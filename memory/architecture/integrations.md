# External Integrations

## 1. Google Gemini AI API

**Purpose:** Two features use Gemini:
- **Smart Transaction Input** — parse natural language (e.g., "lunch McDonalds 45k") into structured `Transaction` fields
- **Monthly Financial Insights** — generate a 3-paragraph advisory from the user's monthly expense breakdown

**Endpoint (configured in appsettings.Development.json):**
```
https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent
```

**Auth:** API key passed as query parameter `?key={apiKey}`

**Request shape:**
```json
{
  "contents": [{ "parts": [{ "text": "<prompt>" }] }]
}
```

**Response parsing path:**
```csharp
root.GetProperty("candidates")[0]
    .GetProperty("content")
    .GetProperty("parts")[0]
    .GetProperty("text")
    .GetString()
```

**Registered as:** `HttpClient` via `AddHttpClient<IService, Implementation>()` — each scoped instance gets its own typed `HttpClient`.

**Timeout:** `FinancialInsightService` sets `_httpClient.Timeout = TimeSpan.FromSeconds(20)`. `GeminiSmartInputService` uses the default HttpClient timeout.

**Failure handling:**
- `GeminiSmartInputService`: throws `Exception("Failed to parse input with Gemini API")` on non-success HTTP → propagated to controller → `BadRequest(ex.Message)`
- `FinancialInsightService`: catches exception → graceful fallback: "Your top spending category this month is {X}. Unfortunately our AI advisor is currently unavailable..."

**Known issue:** If Gemini returns JSON wrapped in \`\`\`json fences despite the prompt saying "no markdown formatting", both services strip them:
```csharp
if (textResult.StartsWith("```json"))
    textResult = textResult.Replace("```json","").Replace("```","").Trim();
```

**Configuration keys:**
```json
"GeminiSettings": {
  "ApiKey": "<your-key>",
  "Endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
}
```

---

## 2. Gmail SMTP (MailKit)

**Purpose:** Send HTML email reports (daily/weekly/monthly) to a configurable list of recipients.

**Library:** MailKit 4.16.0

**SMTP settings (from `tbl_settings_config`):**
| Key | Value |
|---|---|
| `Email_SmtpHost` | `smtp.gmail.com` |
| `Email_SmtpPort` | `587` |
| `Email_FromEmail` | Gmail sender address |
| `Email_Password` | Gmail App Password (not the Google account password) |
| `Report_EmailTo` | Comma-separated recipient list |

**Connection pattern:**
```csharp
smtp.Connect(smtpHost, smtpPort, useSsl: false)  // STARTTLS on 587
smtp.Authenticate(fromEmail, password)
smtp.Send(email)
smtp.Disconnect(true)
```

**Important:** `useSsl: false` with port 587 means STARTTLS is used (not SSL from the start). This is correct for Gmail SMTP.

**Failure behavior:** `EmailService.Send()` throws on any SMTP failure — the caller (`ReportService.SendReport()`) catches and logs but does not rethrow (report send failures are silently logged).

---

## 3. Redis Cache

**Purpose:** Cache two expensive compound data structures:
- **Dashboard summary** (`DailySummaryVM`) — 10-minute TTL, keyed by `userId + date + hour`
- **Financial Insights** (`FinancialInsightDto`) — 24-hour TTL, keyed by `userId + year-month`

**Connection string (appsettings.Development.json):**
```
localhost:6379,abortConnect=false
```
`abortConnect=false` means the app starts even if Redis is unreachable.

**Instance prefix:** `SpendMate_` (all cache keys are prefixed automatically by the distributed cache framework)

**Cache key examples:**
```
SpendMate_Dashboard_Summary_1_20260928_17
SpendMate_FinancialInsights_Monthly_1_202609
```

**Serialization:** `System.Text.Json.JsonSerializer` (UTF-8 JSON strings stored in Redis)

**Failure handling:** `RedisCacheService` catches all exceptions in `GetAsync`, `SetAsync`, `RemoveAsync` and logs them (does not rethrow). `FinancialInsightService` wraps both Redis calls in try-catch with `LogWarning` — Redis failures are fully non-fatal.

**Interface:**
```csharp
Task<T> GetAsync<T>(string key)
Task SetAsync<T>(string key, T value, TimeSpan? absoluteExpireTime = null)
Task RemoveAsync(string key)
```
Default TTL (when not specified): 60 minutes.

---

## 4. BCA Bank Statement Import (EPPlus)

**Purpose:** Import transaction history from BCA (Bank Central Asia) bank statements in either `.xlsx` (Excel) or `.csv` format.

**Library:** EPPlus 8.5.4 (non-commercial license set as `SetNonCommercialOrganization("SpendMate")`)

**File format (BCA eStatement):**
| Column | Content |
|---|---|
| 1 | Date (`dd/MM/yyyy`) or "PEND" (continuation of previous date) |
| 2 | Description/Note |
| 4 | Amount (BCA format: `.` thousands separator, `,` decimal — both stripped) |
| 5 | `CR` (credit/income) or `DB` (debit/expense) |

**Keyword → Category mapping (TransactionService.UploadBcaStatement):**
| Keyword in note | → Category |
|---|---|
| KARTU KREDIT | `Credit Card Statement` |
| TOKOPEDIA | `SHOPPING` |
| HARTADINATA | `GOLD 5GR` |
| DIGITRAVEL | `RECREATION` |
| FRANKY, EVE | `Franky's family` |
| FAM, FEITY, FETTY | `FRANKY PARENTS` |
| JOVITA | `EVE PARENTS` |
| (default) | `OTHERS` |

**CSV delimiter detection:** Counts occurrences of `;` vs `,` across the full file; uses the more frequent one.

**Known quirk:** Debug `Console.WriteLine` statements remain in the upload code (not `_logger.LogInformation`). These write directly to stdout.
