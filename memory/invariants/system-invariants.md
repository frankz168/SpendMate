# System Invariants & Risk Catalog

> This document records constraints that must hold for the system to behave correctly, known bugs, and safe-change checklists. Before modifying any area, read the relevant section.

---

## 🔴 Critical Bugs / Known Data Issues

### INV-001: `spendmate_report_getdata` Missing User Filter (OLD SQL Dump)

**Status:** Likely fixed in `migrate_v12_report_fixes.sql` but the canonical `SQL/SpendMate.sql` dump still shows the OLD version without userid filter.

**Risk:** If the live DB still has the old function, email reports will aggregate ALL users' transactions.

**Verification:**
```sql
\df spendmate_report_getdata
-- Check parameter list: should include p_userid INT
```

**Safe-change rule:** Never apply `SQL/SpendMate.sql` directly to a production DB. Always use incremental migration scripts.

---

### INV-002: `UserId = 1` Hardcoded in Multiple Places

**Locations:**
- `Transaction.cs` line 8: `public int UserId { get; set; } = 1;`
- `ReportSchedulerService.cs` line 69/93/114: `service.SendReport("daily/weekly/monthly", 1)`
- `ReportSchedulerService.cs` line 138: `spendmate_automation_runrecurring(1)`

**Risk:** Adding a second user without fixing these will cause all scheduler actions (reports, recurring cloning) to apply to userId=1 only. New users' transactions will be inserted with userId=1 if the form doesn't explicitly override it.

**Safe-change rule:** Before adding multi-user support, audit all these hardcoded references and the `GetUserId()` call in each controller action.

---

### INV-003: `spendmate_transaction_insert` — Createdate Parameter Mismatch

**Context:** `TransactionRepository.Insert()` passes `@Createdate` in the Dapper params dict:
```csharp
Createdate = (model.Createdate == default || ...) ? DateTime.Now : model.Createdate
```
But the SP signature in the main dump doesn't declare `p_createdate`. The SP uses `createdate = NOW()` internally.

**Risk:** If the live SP was updated (in `migrate_v13_user_sp.sql`) to accept `p_createdate`, then the above C# logic matters and BCA upload dates will be preserved. If the live SP ignores it, all imported transactions get `NOW()` as their date.

**Verification:**
```sql
SELECT proargnames FROM pg_proc WHERE proname = 'spendmate_transaction_insert';
```

---

### INV-004: `Console.WriteLine` Debug Statements in Production Code

**Location:** `TransactionService.UploadBcaStatement()` lines 230, 234

**Risk:** These write to stdout, which shows in process logs but not in Serilog structured logs. They cannot be filtered by log level and may expose transaction data.

**Safe-change rule:** Replace with `_logger.LogDebug(...)` before any production deployment.

---

## 🟡 Design Constraints / Rules That Must Hold

### INV-005: All DB Access Must Go Through Stored Procedures

**Rule:** No inline SQL against tables except `ConfigRepository.SetString()` (UPDATE to tbl_settings_config). All new repository methods must call stored procedures.

**Rationale:** See [`decisions/implementation-rationale.md`](../decisions/implementation-rationale.md).

**Enforcement:** Code review. There is no DB-level enforcement.

---

### INV-006: Transaction Type Must Be Exactly 'Income', 'Expense', or 'Transfer'

**Rule:** The `Transaction.Type` property and the SP insert both accept `VARCHAR(20)`. No DB-level check constraint exists.

**Dependent behavior:**
- `GetTotalByType` filters by exact string match
- `spendmate_budget_getmonthlyrecap` filters `IN ('Expense', 'Transfer')` for actual spend
- `spendmate_dashboard_get6monthtrend` filters `IN ('Expense', 'Transfer')` for expense trend
- Report email only counts Expense for the budget comparison

**Risk:** A typo like `'expense'` (lowercase) will cause silent data loss — the transaction inserts successfully but never appears in reports/budget/trend.

**Safe-change rule:** Always use string literals or enum-equivalent constants. Consider adding a DB CHECK constraint: `CHECK (type IN ('Income', 'Expense', 'Transfer'))`.

---

### INV-007: Date Ranges Use Exclusive Upper Bound

**Rule:** All range queries use `createdate >= p_from AND createdate < p_to`. C# always adds `+1 day` to the `to` parameter.

**Risk:** Forgetting the `+1 day` offset in a new repository method will silently exclude all transactions on the last day of the requested range.

**Safe-change rule:** When writing new date-range repository methods, always follow the pattern:
```csharp
var toInclusive = to.Date.AddDays(1);
// Then pass toInclusive as the @ToDate parameter
```

---

### INV-008: Recurring Automation is Idempotent by Design

**Rule:** `spendmate_automation_runrecurring` checks for existing clones before creating new ones. Running it multiple times in a month produces at most one clone per template.

**Collision detection:** Matches on `category + amount + type + note LIKE '[Auto-Recurring]%' + is_recurring = FALSE + same month`.

**Risk if broken:** Duplicate recurring transactions. If a user manually creates a transaction matching the collision criteria, the automation will think the clone already exists and skip it.

**Safe-change rule:** Never change the `[Auto-Recurring] ` note prefix. Never remove the existence check from the stored procedure.

---

### INV-009: Scheduler Uses In-Memory Last-Run Tracking

**Rule:** `ReportSchedulerService` tracks `_lastDailyRun`, `_lastWeeklyRun`, `_lastMonthlyRun`, `_lastRecurringRun` as instance fields. These reset on app restart.

**Risk:** If the app restarts between 07:09 and 07:11 (the daily report window), the report may fire twice (once before restart, once after on the new instance). Alternatively, if the app was down during the window, the report is skipped entirely — there is no catch-up mechanism.

**Safe-change rule:** The current design is acceptable for a single-instance personal app. For reliability, consider persisting last-run timestamps to the database.

---

### INV-010: Authentication Cookie — No Server-Side Session

**Rule:** Auth state lives entirely in the browser cookie (30-day, persistent). There is no server-side session store or token revocation list.

**Risk:** A stolen cookie provides 30-day access. A password change does not invalidate existing cookies.

**Safe-change rule:** For security-critical operations, consider adding a `SecurityStamp` mechanism or reducing cookie lifetime.

---

### INV-011: `categories.name` Used as FK by String in `transactions`

**Rule:** `transactions.category` is a free-text `VARCHAR(50)` that matches `categories.name` by value. There is **no FK constraint** between them.

**Risk:** 
- Renaming a category name does not update historical transactions
- Importing data (BCA upload) can create categories that don't exist in the master table
- Typos silently create orphan categories in reports

**Safe-change rule:** Do not rename category names casually. If renaming is needed, also update all `transactions.category` values to match.

---

## Safe-Change Checklists

### Adding a New Stored Procedure
- [ ] Name follows `spendmate_{domain}_{action}` convention
- [ ] Add DROP IF EXISTS before CREATE in migration script
- [ ] Add matching migration file `migrate_v{N}_{description}.sql`
- [ ] Add method to the interface (e.g., `ITransactionRepository`)
- [ ] Implement in the concrete repository class
- [ ] Pass `@UserId` parameter for any user-scoped query
- [ ] Test date range: if applicable, use `>= from AND < to` pattern

### Adding a New Transaction Field
- [ ] Add column to `transactions` table via new migration
- [ ] Update `spendmate_transaction_insert` and `_update` signatures
- [ ] Update all `RETURNS TABLE(...)` functions to include the new column
- [ ] Add property to `Transaction.cs` model
- [ ] Update `TransactionRepository.Insert()` and `Update()` Dapper param dicts
- [ ] Verify Dapper type casting (add `::type` if needed)
- [ ] Update Excel export columns in `TransactionController.ExportExcel()`

### Deploying a Schema Change
- [ ] Never apply full `SpendMate.sql` to production — it DROPs all objects first
- [ ] Create an incremental `migrate_v{N}_{description}.sql`
- [ ] Test migration on a dev copy of the DB first
- [ ] Verify all affected stored procedures still work after column changes
