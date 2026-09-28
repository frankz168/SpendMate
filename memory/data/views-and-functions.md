# Views and Functions

> SpendMate uses **no PostgreSQL views**. All query logic is encapsulated in **stored functions** (PL/pgSQL).

For complete stored function documentation, see [`stored-procedures.md`](stored-procedures.md).

---

## C# Application-Level Computed Values

These are "virtual views" computed in the service/controller layer, not in the database:

### `DailySummaryVM` (DashboardService)
Assembled by `DashboardService.GetDailySummary()`:

| Property | Source |
|---|---|
| `TodayIncome` | `GetTotalByType(userId, today, now, "Income")` |
| `TodayExpense` | `GetTotalByType(userId, today, now, "Expense")` |
| `TodayTransfer` | `GetTotalByType(userId, today, now, "Transfer")` |
| `MonthlyIncome` | `GetTotalByType(userId, monthStart, now, "Income")` |
| `MonthlyExpense` | `GetTotalByType(userId, monthStart, now, "Expense")` |
| `MonthlyTransfer` | `GetTotalByType(userId, monthStart, now, "Transfer")` |
| `NetBalance` | `MonthlyIncome - MonthlyExpense` |
| `Budget` | `config.GetDecimal("MonthlyBudget")` |
| `RemainingBudget` | `Budget - MonthlyExpense` |
| `Items` | `GetReportData("monthly", userId)` — category breakdown |
| `TrendItems` | `Get6MonthTrend(userId)` — 6-month income/expense trend |

### `MonthlyBudget` (BudgetController)
Assembled by `spendmate_budget_getmonthlyrecap()`:

| Column | Source |
|---|---|
| `TargetAmount` | `monthly_budgets.target_amount` → `categories.default_target` → `0` |
| `ActualAmount` | Sum of matching transactions (Expense + Transfer) in period |
| Variance (Excel only) | `TargetAmount - ActualAmount` (computed in BudgetController.ExportExcel) |

### `ReportItem` (ReportService + Dashboard)
Returned by `spendmate_report_getdata(type, userId)`:
- `Category` (string)
- `Total` (decimal)

Used to build the email body and dashboard breakdown list.

---

## No Database Views Used

The PostgreSQL schema contains only tables and functions. There are no `CREATE VIEW` statements in `SpendMate.sql` or any migration file. The decision to use stored functions instead of views was made to centralize all data-access logic into named, versionable functions. See [`decisions/implementation-rationale.md`](../decisions/implementation-rationale.md).
