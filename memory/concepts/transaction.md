# Transaction Lifecycle

## Overview

A transaction is the atomic financial record in SpendMate. It represents a single movement of money: income received, expense paid, or a transfer between accounts/people.

---

## Transaction States

SpendMate transactions have no explicit "state" field. The lifecycle is implicit:

```
[User Input / AI Parse / BCA Import]
    → INSERT (is_recurring = FALSE, regular transaction)
    → [Optional: UPDATE if edited]
    → [Optional: DELETE]

[User marks recurring template]
    → INSERT (is_recurring = TRUE, acts as template)
    → Scheduler clones it each month → new row (is_recurring = FALSE, note = '[Auto-Recurring] …')
    → Template remains, clones accumulate each month
```

---

## Fields

| Field | Type | Notes |
|---|---|---|
| `Id` | int | DB auto-increment |
| `UserId` | int | Defaults to `1` in C# model |
| `Type` | string | Exactly: `'Income'`, `'Expense'`, `'Transfer'` |
| `Amount` | decimal | Positive number (IDR) |
| `Category` | string | Free text matching `categories.name` |
| `Destination` | string? | Optional; used for Transfer type |
| `Note` | string? | Free text description |
| `Createdate` | DateTime | Actual transaction date (not insert time) |
| `IsRecurring` | bool | TRUE = template; FALSE = actual transaction |

---

## Ways a Transaction Can Be Created

1. **Manual form submission** — user fills form on `/Transaction/Index` → POST `/Transaction/Save`
2. **Gemini Smart Input** — user types natural language → Gemini parses → user confirms → POST `/Transaction/Save`
3. **BCA Statement Upload** — bulk import via POST `/Transaction/UploadBcaStatement` (CSV or Excel)
4. **Recurring Automation** — scheduler runs `spendmate_automation_runrecurring(1)` daily at 10:00 AM

---

## Createdate Guard

Multiple places guard against invalid dates:

```csharp
// In TransactionService.Save():
if (model.Createdate == default || model.Createdate <= DateTime.MinValue || model.Createdate.Year < 1970)
    model.Createdate = DateTime.Now;

// In TransactionRepository.Insert():
Createdate = (model.Createdate == default || model.Createdate <= DateTime.MinValue || model.Createdate.Year < 1970)
    ? DateTime.Now
    : model.Createdate
```

This is needed because:
- Gemini always returns `Createdate = DateTime.Now` (ignores natural-language dates)
- BCA import sets dates from the file (historical dates)
- Manual form may send an empty date field

---

## Category Assignment

Category is stored as a free-text string in `transactions.category`. The value must match `categories.name` for the transaction to appear correctly in budget reports. Transactions can have categories not in the master list (e.g., `Credit Card Statement` used in BCA imports).

---

## Related Code

| Symbol | File |
|---|---|
| `Transaction` model | [`Models/Transaction.cs`](file:///Users/frankz168/SpendMate/Models/Transaction.cs) |
| `TransactionService` | [`Service/TransactionService.cs`](file:///Users/frankz168/SpendMate/Service/TransactionService.cs) |
| `TransactionRepository` | [`Repositories/TransactionRepository.cs`](file:///Users/frankz168/SpendMate/Repositories/TransactionRepository.cs) |
| `TransactionController` | [`Controllers/TransactionController.cs`](file:///Users/frankz168/SpendMate/Controllers/TransactionController.cs) |
| `ITransactionRepository` | [`Interfaces/ITransactionRepository.cs`](file:///Users/frankz168/SpendMate/Interfaces/ITransactionRepository.cs) |
