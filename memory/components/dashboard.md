# Dashboard Component

## Overview

The dashboard is the main home screen after login. It aggregates today's and monthly financial summary data and displays it alongside a 6-month trend chart.

---

## Route

```
GET /Dashboard/Index
```

Controller: `DashboardController.Index()` (registered as [Authorize])

---

## Data Composition

`DashboardService.GetDailySummaryAsync(userId)` returns a `DailySummaryVM`:

| Field | Time scope | Source |
|---|---|---|
| `TodayIncome` | Today | `spendmate_transaction_gettotalbytype` |
| `TodayExpense` | Today | same |
| `TodayTransfer` | Today | same |
| `MonthlyIncome` | Month-to-date | same |
| `MonthlyExpense` | Month-to-date | same |
| `MonthlyTransfer` | Month-to-date | same |
| `NetBalance` | Month | `MonthlyIncome - MonthlyExpense` (C#) |
| `Budget` | Static | `tbl_settings_config['MonthlyBudget']` |
| `RemainingBudget` | Month | `Budget - MonthlyExpense` (C#) |
| `Items` | Month | `spendmate_report_getdata('monthly', userId)` |
| `TrendItems` | 6 months | `spendmate_dashboard_get6monthtrend(userId)` |

---

## Caching

The entire `DailySummaryVM` is cached in Redis:
- **Key:** `SpendMate_Dashboard_Summary_{userId}_{yyyyMMdd_HH}`
- **TTL:** 10 minutes
- Cache miss triggers all DB calls above (6 `GetTotalByType` + 1 config + 1 report + 1 trend)
- No active invalidation on transaction save — relies on natural TTL expiry

---

## Financial Insights (AI Panel)

A separate panel on the dashboard calls `GET /api/insights/monthly` via client-side JavaScript to display Gemini AI insights. This call is asynchronous and non-blocking — the dashboard renders without it.

---

## Related Code

| Symbol | File |
|---|---|
| `DashboardService` | [`Service/DashboardService.cs`](file:///Users/frankz168/SpendMate/Service/DashboardService.cs) |
| `DashboardController` | [`Controllers/DashboardController.cs`](file:///Users/frankz168/SpendMate/Controllers/DashboardController.cs) |
| `DashboardRepository` | [`Repositories/DashboardRepository.cs`](file:///Users/frankz168/SpendMate/Repositories/DashboardRepository.cs) |
| `DailySummaryVM` | [`ViewModels/DailySummaryVM.cs`](file:///Users/frankz168/SpendMate/ViewModels/DailySummaryVM.cs) |
| `TrendItem` | [`Models/TrendItem.cs`](file:///Users/frankz168/SpendMate/Models/TrendItem.cs) |
| `ReportItem` | [`Models/ReportItem.cs`](file:///Users/frankz168/SpendMate/Models/ReportItem.cs) |
| Dashboard View | [`Views/Dashboard/`](file:///Users/frankz168/SpendMate/Views/Dashboard/) |
