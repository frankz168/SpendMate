# Budget & Categories Concept

## Overview

SpendMate models household budgets using two interacting concepts:
1. **Categories** — a master list of spending/savings buckets with group type and optional default targets
2. **Monthly Budgets** — per-user, per-month records that override category defaults with specific targets and track payment status

---

## Category Groups

| Group | Purpose | Example Categories |
|---|---|---|
| `Fixed` | Mandatory recurring payments (fixed amount) | KPR HOME TENJO, ELECTRIC TOKEN, PDAM |
| `Savings` | Investment and savings allocations | NANOVEST, GOLD 5GR, SILVER 100GR |
| `Variable` | Discretionary/flexible spending | DINING OUT, SHOPPING, RECREATION |

**GroupType determines ordering** in the budget recap: Fixed → Savings → Variable → Other.

---

## Budget Recap Logic

The `spendmate_budget_getmonthlyrecap()` function assembles a comprehensive view:

```
AllCategories = UNION of:
  1. Categories from actual transactions that month
  2. All active categories in the master table
  3. Categories that have a monthly_budgets row for that period

For each category:
  TargetAmount = monthly_budgets.target_amount
              ?? categories.default_target
              ?? 0
  ActualAmount = SUM(transactions.amount WHERE type IN ('Expense','Transfer') AND month/year match)
              ?? 0
  IsPaid       = monthly_budgets.is_paid ?? FALSE
```

This means even if a budget row doesn't exist yet (no explicit plan set), the category still appears in the recap if there are actual transactions for it.

---

## Budget Save / Upsert

`spendmate_budget_save_monthly` does an UPSERT:
1. Looks up or creates the category in `categories`
2. INSERTs a `monthly_budgets` row with the target; ON CONFLICT updates `target_amount` and `is_paid`

This means setting a budget target is idempotent — safe to call multiple times.

---

## IsPaid Semantics

`is_paid` is a manual checkbox the user ticks to indicate they've already made this payment. It:
- Is highlighted yellow in the Excel export ("*NOTE: THE YELLOW ROW IS ALREADY PAID BY FRANKY*")
- Does **not** affect financial calculations (actual amounts still come from transactions)
- Is persisted per month per category per user

---

## Default Targets (Seed Data Summary, IDR)

| Category | Monthly Default |
|---|---|
| KPR HOME TENJO | 6,300,000 |
| KPR HOME CRB | 1,200,000 |
| EVE PARENTS | 4,000,000 |
| INTERNET & KUOTA | 457,000 |
| ELECTRIC TOKEN | 500,000 |
| PDAM | 115,800 |
| TRANSPORT / GAS | 150,000 |
| LAUNDRY | 35,000 |
| NANOVEST | 5,000,000 |
| GOLD 5GR | 12,071,625 |
| SILVER 100GR | 6,048,000 |
| FRANKY PARENTS, GROCERIES, DINING OUT, RECREATION, SHOPPING, OTHERS | 0 |

**Total configured budget:** `MonthlyBudget` config key = `61,260,000` IDR

---

## Related Code

| Symbol | File |
|---|---|
| `Category` model | [`Models/Category.cs`](file:///Users/frankz168/SpendMate/Models/Category.cs) |
| `MonthlyBudget` model | [`Models/MonthlyBudget.cs`](file:///Users/frankz168/SpendMate/Models/MonthlyBudget.cs) |
| `BudgetRepository` | [`Repositories/BudgetRepository.cs`](file:///Users/frankz168/SpendMate/Repositories/BudgetRepository.cs) |
| `CategoryRepository` | [`Repositories/CategoryRepository.cs`](file:///Users/frankz168/SpendMate/Repositories/CategoryRepository.cs) |
| `BudgetController` | [`Controllers/BudgetController.cs`](file:///Users/frankz168/SpendMate/Controllers/BudgetController.cs) |
| `SettingsController` | [`Controllers/SettingsController.cs`](file:///Users/frankz168/SpendMate/Controllers/SettingsController.cs) |
