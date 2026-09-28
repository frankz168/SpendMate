# Stored Procedures (PostgreSQL Functions)

> All functions live in the `public` schema. They are called from C# Dapper repositories.  
> **Authoritative source:** `SQL/SpendMate.sql` (canonical dump), `SQL/migrate_v9_recurring.sql` (v9 additions).

---

## Naming Convention

```
spendmate_{domain}_{action}
```

| Domain prefix | Module |
|---|---|
| `transaction_` | Transaction CRUD + export |
| `dashboard_` | Dashboard aggregations |
| `budget_` | Monthly budget recap + save |
| `report_` | Email report data |
| `master_` | Category master data |
| `config_` | Runtime configuration |
| `user_` | User management |
| `automation_` | Background automation |

---

## Transaction Functions

### `spendmate_transaction_insert`
```sql
RETURNS integer
(p_userid INT, p_type VARCHAR, p_amount NUMERIC, p_category VARCHAR, 
 p_destination VARCHAR, p_note TEXT, p_is_recurring BOOLEAN DEFAULT false)
```
- Inserts into `transactions`, sets `createdate = NOW()`
- Returns the new `id`
- Note: C# layer passes an additional `@Createdate` parameter in the Dapper call (not used in SP — SP ignores it and uses `NOW()`)

> **⚠ Known mismatch:** The C# `TransactionRepository.Insert` passes `@Createdate` in the Dapper param dict, but the SP signature does not have a `p_createdate` parameter. This works because Dapper sends it but Postgres ignores extra named parameters. The `migrate_v13_user_sp.sql` adds a `p_createdate` parameter — **verify the live DB SP signature before modifying.**

### `spendmate_transaction_update`
```sql
RETURNS void
(p_id INT, p_userid INT, p_type VARCHAR, p_amount NUMERIC, p_category VARCHAR,
 p_destination VARCHAR, p_note TEXT, p_is_recurring BOOLEAN DEFAULT false)
```
- Updates `type`, `amount`, `category`, `destination`, `note`, `is_recurring`
- Does NOT update `createdate`
- Scoped to `WHERE id = p_id AND userid = p_userid`

### `spendmate_transaction_delete`
```sql
RETURNS void
(p_id INT, p_userid INT)
```
- Hard-deletes the row. No soft-delete.

### `spendmate_transaction_getbyid`
```sql
RETURNS TABLE(id, type, amount, category, destination, note, createdate, is_recurring)
(p_id INT, p_userid INT)
```
- Single row by id + userid (user-scoped).

### `spendmate_transaction_getlist`
```sql
RETURNS TABLE(id, type, amount, category, destination, note, createdate, is_recurring)
(p_userid INT, p_from TIMESTAMP, p_to TIMESTAMP)
```
- Range query: `createdate >= p_from AND createdate < p_to`
- Ordered by `createdate DESC`

### `spendmate_transaction_exportall`
```sql
RETURNS TABLE(id, type, amount, category, destination, note, createdate, is_recurring)
(p_userid INT, p_from TIMESTAMP, p_to TIMESTAMP)
```
- Nullable `from`/`to` support: `p_from IS NULL OR createdate >= p_from`
- Same columns as `getlist`

### `spendmate_transaction_gettotalbytype`
```sql
RETURNS numeric
(p_userid INT, p_from TIMESTAMP, p_to TIMESTAMP, p_type VARCHAR)
```
- `SUM(amount)` filtered by `userid`, date range, and `type`
- Returns `0` on no match via `COALESCE`

---

## Dashboard Functions

### `spendmate_dashboard_getdailytotal`
```sql
RETURNS numeric
(p_userid INT)
```
- Sum of all `Expense` transactions for the current calendar day (`createdate::date = CURRENT_DATE`)

### `spendmate_dashboard_getdailysummary`
```sql
RETURNS TABLE(category VARCHAR, total NUMERIC)
(p_userid INT)
```
- Per-category expense totals for today only
- Returns `Expense` type only

### `spendmate_dashboard_get6monthtrend`
```sql
RETURNS TABLE(month VARCHAR, income NUMERIC, expense NUMERIC)
(p_userid INT)
```
- Generates a 6-month series (rolling, current month + 5 prior) using `generate_series`
- `income` = `SUM(amount) FILTER (WHERE type = 'Income')`
- `expense` = `SUM(amount) FILTER (WHERE type IN ('Expense', 'Transfer'))`
- Month label format: `'Mon YYYY'` (e.g., `'Sep 2026'`)
- Ordered chronologically

---

## Budget Functions

### `spendmate_budget_getmonthlyrecap`
```sql
RETURNS TABLE("Id" INT, "GroupType" VARCHAR, "Category" VARCHAR, 
              "TargetAmount" NUMERIC, "ActualAmount" NUMERIC, "IsPaid" BOOLEAN)
(p_userid INT, p_year INT, p_month INT)
```
Complex CTE logic:
1. `MonthlyTx` — sums actual spending from `transactions` (Expense + Transfer) for given month/year
2. `AllCategories` — UNION of: transaction categories, active categories master, and budget-linked categories
3. Final SELECT joins all sources to produce a unified view
4. `TargetAmount`: from `monthly_budgets.target_amount` → fallback to `categories.default_target` → fallback to `0`
5. `ActualAmount`: from `MonthlyTx` sum → fallback to `0`
6. Ordered by: Fixed (1) → Savings (2) → Variable (3) → then alphabetically

### `spendmate_budget_save_monthly`
```sql
RETURNS void
(p_userid INT, p_year INT, p_month INT, p_group_type VARCHAR, 
 p_category VARCHAR, p_target_amount NUMERIC, p_is_paid BOOLEAN)
```
- Auto-creates category in `categories` if not found (INSERT with `group_type`, `default_target = p_target_amount`)
- Upserts `monthly_budgets` with `ON CONFLICT (userid, year, month, category_id) DO UPDATE`

---

## Report Functions

### `spendmate_report_getdata`
```sql
RETURNS TABLE(category VARCHAR, total NUMERIC)
(p_type VARCHAR, p_userid INT)  -- ⚠ See note
```
- `daily` → expenses since `CURRENT_DATE`
- `weekly` → expenses since `CURRENT_DATE - 7 days`
- `monthly` → expenses in current calendar month (EXTRACT YEAR + MONTH)

> **⚠ CRITICAL BUG:** The version in `SpendMate.sql` (old dump) does NOT filter by `userid`. The migration `SQL/migrate_v12_report_fixes.sql` likely adds the `userid` parameter. **Always verify the live function signature in psql before trusting this doc.** The C# `ReportRepository` passes `@UserId` in the Dapper params, which implies the live SP accepts it.

---

## Master Data Functions

### `spendmate_master_getcategories`
```sql
RETURNS TABLE("Id" INT, "Name" VARCHAR, "GroupType" VARCHAR, "DefaultTarget" NUMERIC, "IsActive" BOOLEAN)
()
```
- Returns all categories ordered by `group_type, name`
- Note: Dapper column names must match exactly — uses quoted identifiers (`"Id"` etc.)

---

## Config Functions

### `spendmate_config_getvalue`
```sql
RETURNS character varying
(p_key VARCHAR)
```
- Simple `SELECT ConfigValue FROM tbl_Settings_Config WHERE ConfigKey = p_key`

---

## User Functions

All added in `SQL/migrate_v13_user_sp.sql`:

### `spendmate_user_getbyusername(p_username VARCHAR)` → single user row
### `spendmate_user_getbyid(p_id INT)` → single user row
### `spendmate_user_getall()` → all user rows
### `spendmate_user_insert(p_name, p_phonenumber, p_username, p_passwordhash)` → void
### `spendmate_user_update(p_id, p_name, p_phonenumber, p_username, p_passwordhash)` → void
### `spendmate_user_delete(p_id INT)` → void

---

## Automation Functions

### `spendmate_automation_runrecurring`
```sql
RETURNS void
(p_userid INT)
```
Key logic:
1. Set `v_start_of_month = date_trunc('month', CURRENT_DATE)::date`
2. Loop all transactions where `userid = p_userid AND is_recurring = TRUE AND date_trunc('month', createdate) < v_start_of_month`
3. For each: check if a clone already exists this month: `note LIKE '[Auto-Recurring]%' AND is_recurring = FALSE AND same category/amount/type AND this month`
4. If not: INSERT clone with `is_recurring = FALSE` and `note = '[Auto-Recurring] ' || original_note`
5. Guard prevents duplicate runs on same month (idempotent)

**Trigger:** Called daily at 10:00 AM via scheduler: `conn.Execute("SELECT spendmate_automation_runrecurring(1);")`

---

## Migration History

| Migration Script | Changes |
|---|---|
| `migrate_v3_v4.sql` | Early schema changes (details in file) |
| `migrate_v6_categories.sql` | Added categories table and master data |
| `migrate_v7_sp_rename.sql` | Renamed stored procedures |
| `migrate_v8_charts.sql` | Added 6-month trend function |
| `migrate_v9_recurring.sql` | Added `is_recurring` column + automation SP |
| `migrate_v10_login.sql` | Login-related changes |
| `migrate_v11_categories_data.sql` | Seeded category data |
| `migrate_v12_report_fixes.sql` | Fixed `spendmate_report_getdata` to include userid filter |
| `migrate_v13_user_sp.sql` | Added all user management stored procedures |
