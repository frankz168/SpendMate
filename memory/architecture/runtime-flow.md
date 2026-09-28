# Runtime Flow — Request Lifecycle

## Standard MVC Request (e.g., Transaction List)

```
Client Browser
    │  GET /Transaction/Index
    ▼
ASP.NET Core Pipeline
    │  Cookie middleware reads auth cookie → populates User claims
    │  [Authorize] attribute checks claims
    ▼
TransactionController.Index()
    │  GetUserId() → reads ClaimTypes.NameIdentifier from User.Claims
    ▼
TransactionService.GetTransactions(userId, from, to)
    │  Stopwatch starts, logs "📥 GetTransactions START"
    ▼
TransactionRepository.GetTransactions(userId, from, to)
    │  DbConnectionFactory.CreateConnection() → new NpgsqlConnection
    │  conn.Query<Transaction>("SELECT * FROM spendmate_transaction_getlist(@UserId, @FromDate::timestamp, @ToDate::timestamp)")
    │  Note: to is extended by +1 day for inclusive range (toInclusive = to.Date.AddDays(1))
    ▼
PostgreSQL: spendmate_transaction_getlist(p_userid, p_from, p_to)
    │  SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    │  FROM transactions WHERE userid = p_userid AND createdate >= p_from AND createdate < p_to
    │  ORDER BY createdate DESC
    ▼
IEnumerable<Transaction> returned up the stack
    ▼
Controller returns View(data) or Json(data)
    ▼
Razor renders HTML  (or JSON for AJAX endpoints)
```

---

## Dashboard Request (Cached Path)

```
GET /Dashboard/Index
    ▼
DashboardController.Index()
    ▼
DashboardService.GetDailySummaryAsync(userId)
    │  cacheKey = "Dashboard_Summary_{userId}_{DateTime.Now:yyyyMMdd_HH}"
    ▼
RedisCacheService.GetAsync<DailySummaryVM>(cacheKey)
    │  IDistributedCache.GetStringAsync(key)
    ├─► [HIT]  deserialize JSON → return DailySummaryVM immediately (skips DB)
    └─► [MISS] falls through to GetDailySummary(userId) synchronous path:
               ┌─ GetTotalByType(userId, todayFrom, to, "Income")    ─ spendmate_transaction_gettotalbytype
               ├─ GetTotalByType(userId, todayFrom, to, "Expense")
               ├─ GetTotalByType(userId, todayFrom, to, "Transfer")
               ├─ GetTotalByType(userId, monthFrom, to, "Income")
               ├─ GetTotalByType(userId, monthFrom, to, "Expense")
               ├─ GetTotalByType(userId, monthFrom, to, "Transfer")
               ├─ GetDecimal("MonthlyBudget")                        ─ spendmate_config_getvalue
               ├─ GetReportData("monthly", userId)                   ─ spendmate_report_getdata
               └─ Get6MonthTrend(userId)                             ─ spendmate_dashboard_get6monthtrend
               └─► RedisCacheService.SetAsync(cacheKey, vm, 10min)
    ▼
DailySummaryVM returned to controller → View renders dashboard
```

**Cache key changes every hour** (format `yyyyMMdd_HH`), so the dashboard refreshes naturally within ~60 minutes.

---

## Gemini Smart Input Flow

```
User types: "lunch McDonalds 45000"
    │  POST /Transaction/SmartInput
    │  [FromBody] string input
    ▼
TransactionController.SmartInput()
    ▼
GeminiSmartInputService.ParseNaturalLanguageAsync(input, userId)
    │  Reads GeminiSettings:ApiKey and GeminiSettings:Endpoint from IConfiguration
    │  Constructs prompt with rules: Type ∈ {Income,Expense,Transfer}, Amount decimal, Category string...
    │  POST https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=...
    │  {contents: [{parts: [{text: "<prompt>"}]}]}
    ▼
Gemini API returns candidates[0].content.parts[0].text (JSON string)
    │  Strips ```json fences if present
    │  JsonSerializer.Deserialize<Transaction>(textResult)
    │  Sets transaction.UserId = userId, transaction.Createdate = DateTime.Now
    ▼
Returns Transaction object as JSON to browser
    │  (User can review and submit via POST /Transaction/Save)
    ▼
POST /Transaction/Save([FromBody] Transaction model)
    ▼
TransactionService.Save(model)
    │  model.Id == 0 → Insert; else Update
    ▼
TransactionRepository.Insert(model)
    │  spendmate_transaction_insert(...)
```

---

## Scheduler Tick Flow (every 1 minute)

```
ReportSchedulerService.ExecuteAsync() [BackgroundService]
    │  Loop: await Task.Delay(1 minute)
    ▼
Per tick:
    │  Create IServiceScope
    │  Resolve ReportService, IConfigRepository
    │
    ├── CheckDaily(service, config, now)
    │     config.GetTimeSpan("Report_DailyTime", 07:10)
    │     IsWithinOneMinute(now, target) && _lastDailyRun.Date != now.Date
    │     → service.SendReport("daily", 1)
    │
    ├── CheckWeekly(service, config, now)
    │     config.GetInt("Report_WeeklyDay", 0) → DayOfWeek
    │     now.DayOfWeek == targetDay && IsWithinOneMinute && date-guard
    │     → service.SendReport("weekly", 1)
    │
    ├── CheckMonthly(service, config, now)
    │     config.GetInt("Report_MonthlyDay", 1)
    │     now.Day == targetDay && IsWithinOneMinute && date-guard
    │     → service.SendReport("monthly", 1)
    │
    └── CheckRecurring(serviceProvider, config, now)
          Fixed at 10:00 AM daily
          → conn.Execute("SELECT spendmate_automation_runrecurring(1);")
```

---

## Report Send Flow

```
ReportService.SendReport(type, userId)
    │  Determine date range:
    │    daily   → from = today.Date
    │    weekly  → from = Monday of current week
    │    monthly → from = 1st of current month
    │
    ├── transactionRepo.GetTotalByType(userId, from, to, "Expense")
    ├── reportRepo.GetReportData(type, userId)  ← spendmate_report_getdata (⚠ no userid filter)
    ├── config.GetDecimal("MonthlyBudget")
    │
    ├── BuildTemplate(...)  → HTML string with status, breakdown, top category
    │
    └── config.GetStringList("Report_EmailTo")
            → foreach email: EmailService.Send(to, subject, html)
                  MailKit SmtpClient.Connect("smtp.gmail.com", 587)
                  Authenticate → Send → Disconnect
```

---

## BCA Statement Upload Flow

```
POST /Transaction/UploadBcaStatement (multipart file)
    ▼
TransactionController.UploadBcaStatement(IFormFile file)
    ▼
TransactionService.UploadBcaStatement(stream, fileName, userId)
    │
    ├── If .csv:
    │     StreamReader → read all text
    │     Normalize line endings to \r\n
    │     Auto-detect delimiter (count ; vs ,)
    │     EPPlus LoadFromText() into temp worksheet
    │
    └── If .xlsx:
          EPPlus package.Load(stream)
    │
    │  Loop rows:
    │    Column 1 = date (dd/MM/yyyy or id-ID locale)
    │    "PEND" rows inherit previous row's date
    │    Column 2 = note/description
    │    Column 4 = amount (strip . and , separators)
    │    Column 5 = CR/DB type → "Income"/"Expense"
    │    Keyword-based category mapping (TOKOPEDIA→SHOPPING, HARTADINATA→GOLD 5GR, etc.)
    │    Insert each row via TransactionRepository.Insert()
```

---

## Financial Insight Flow

```
GET /api/insights/monthly
    ▼
InsightsController.GetMonthlyInsights()
    ▼
FinancialInsightService.GetMonthlyInsightsAsync(userId)
    │
    ├─► Redis.GetAsync<FinancialInsightDto>("FinancialInsights_Monthly_{userId}_{yyyyMM}")
    │     [HIT] → return cached (24-hour TTL, resets monthly by cache key)
    │     [MISS] falls through
    │
    ├── transactionRepo.GetTransactions(userId, startOfMonth, now)
    │     .Where(t => t.Type == "Expense")
    │     GroupBy Category → summaryJson
    │
    ├── POST Gemini API with 3-paragraph advisor prompt
    │     Timeout: 20 seconds
    │     [Fallback on error: "Your top spending category is X…"]
    │
    ├── Build FinancialInsightDto { Insights, GeneratedAt }
    │
    └── Redis.SetAsync(cacheKey, result, 24h)  ← [Graceful: skip on Redis failure]
    │
    ▼
return Ok(dto)
```
