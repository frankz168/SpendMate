# Gemini AI Integration Component

## Services Using Gemini

| Service | Feature | Cached? |
|---|---|---|
| `GeminiSmartInputService` | Parse natural language → Transaction JSON | No |
| `FinancialInsightService` | Generate monthly financial advice text | Yes (24h Redis) |

---

## Configuration

```json
// appsettings.Development.json
"GeminiSettings": {
  "ApiKey": "<secret>",
  "Endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
}
```

**Never commit the API key to git.** Verify `.gitignore` excludes `appsettings.Development.json`.

---

## Smart Input Service (`GeminiSmartInputService`)

**Interface:** `IGeminiSmartInputService`
```csharp
Task<Transaction> ParseNaturalLanguageAsync(string input, int userId)
```

**Prompt design:** Tells Gemini to return ONLY raw JSON (no markdown) matching:
```json
{ "Type": "Expense", "Amount": 0.0, "Category": "", "Note": "", "Destination": "" }
```

**Failure mode:** Throws `Exception` on non-2xx response. Controller catches and returns `BadRequest(ex.Message)`.

**Gemini response trust:** The response is deserialized directly into `Transaction`. Gemini does not always follow instructions exactly — the markdown fence stripper is a defensive guard.

**UserId and date:** Always set after deserialization, never from Gemini's output:
```csharp
transaction.UserId = userId;
transaction.Createdate = DateTime.Now;
```

---

## Financial Insight Service (`FinancialInsightService`)

**Interface:** `IFinancialInsightService`
```csharp
Task<FinancialInsightDto> GetMonthlyInsightsAsync(int userId)
```

**Data sent to Gemini:** Aggregated category-total JSON (not raw transactions):
```json
[{"Category":"SHOPPING","Total":1234000}, ...]
```

**Prompt design:** Asks for a 3-paragraph advisory:
- Para 1: Summarize spending habits
- Para 2: Areas of concern / high spending
- Para 3: Actionable advice for next month

**Timeout:** 20 seconds (set on HttpClient instance in constructor).

**Graceful degradation:**
```csharp
aiInsightText = $"Your top spending category this month is {highestCategory}. 
Unfortunately, our AI advisor is currently unavailable...";
```

**Cache strategy:**
- Key: `FinancialInsights_Monthly_{userId}_{yyyyMM}`
- TTL: 24 hours
- The monthly key ensures insights reset each month
- Redis failure on read/write is non-fatal (logged as Warning)

---

## API Endpoint for Insights

```
GET /api/insights/monthly
Authorization: Cookie [Authorize]
Returns: 200 OK { "insights": "...", "generatedAt": "..." }
         500 on unexpected error
```

Controller: `InsightsController` decorated `[ApiController]` + `[Route("api/[controller]")]`

---

## `FinancialInsightDto` Model

```csharp
public class FinancialInsightDto
{
    public string Insights { get; set; }
    public DateTime GeneratedAt { get; set; }
}
```

---

## Related Code

| Symbol | File |
|---|---|
| `GeminiSmartInputService` | [`Service/GeminiSmartInputService.cs`](file:///Users/frankz168/SpendMate/Service/GeminiSmartInputService.cs) |
| `FinancialInsightService` | [`Service/FinancialInsightService.cs`](file:///Users/frankz168/SpendMate/Service/FinancialInsightService.cs) |
| `IGeminiSmartInputService` | [`Interfaces/IGeminiSmartInputService.cs`](file:///Users/frankz168/SpendMate/Interfaces/IGeminiSmartInputService.cs) |
| `IFinancialInsightService` | [`Interfaces/IFinancialInsightService.cs`](file:///Users/frankz168/SpendMate/Interfaces/IFinancialInsightService.cs) |
| `InsightsController` | [`Controllers/InsightsController.cs`](file:///Users/frankz168/SpendMate/Controllers/InsightsController.cs) |
| `FinancialInsightDto` | [`Models/FinancialInsightDto.cs`](file:///Users/frankz168/SpendMate/Models/FinancialInsightDto.cs) |
