# Data Access Patterns

## Core Principle: Stored-Procedures Only

**All database reads and writes go through PostgreSQL stored procedures (functions).** No repository writes inline SQL directly against tables — the sole exception is `ConfigRepository.SetString()` which issues a direct `UPDATE tbl_settings_config SET configvalue = @Value WHERE configkey = @Key`. Every other operation uses a `SELECT function_name(args)` or `SELECT * FROM function_name(args)` call pattern.

---

## Connection Management

```csharp
// DbConnectionFactory (Singleton)
public IDbConnection CreateConnection()
{
    return new NpgsqlConnection(_config.GetConnectionString("DefaultConnection"));
}
```

- Connections are **not pooled explicitly** — Npgsql maintains a connection pool internally.
- Pattern: `using var conn = _db.CreateConnection();` — one connection per repository method call.
- Connections are opened on first Dapper call and disposed at end of `using` block.
- `DbConnectionFactory` is **Singleton** but `CreateConnection()` produces a new NpgsqlConnection each time (safe for multi-thread use).

---

## Dapper Mapping Patterns

### Typed Query (strongly typed model)
```csharp
conn.Query<Transaction>("SELECT * FROM spendmate_transaction_getlist(@UserId, @FromDate::timestamp, @ToDate::timestamp);", new { UserId, FromDate, ToDate })
```

### Dynamic Query (used in export, dashboard summary)
```csharp
conn.Query("SELECT * FROM spendmate_dashboard_getdailysummary(@UserId);", new { UserId })
// Returns IEnumerable<dynamic>; properties accessed as x.createdate, x.amount etc (lowercase)
```

### Scalar
```csharp
conn.ExecuteScalar<decimal>("SELECT spendmate_transaction_gettotalbytype(@UserId, @From::timestamp, @To::timestamp, @Type::VARCHAR);", ...)
```

### Execute (void stored proc)
```csharp
conn.Execute("SELECT spendmate_transaction_delete(@id, @UserId);", new { id, UserId })
conn.Execute("SELECT spendmate_automation_runrecurring(1);")
```

**Note:** Postgres functions returning `void` are called with `SELECT funcname(args)` — Dapper's `Execute()` works correctly here because there is no result set to map.

---

## Date Range Handling (Off-by-one Guard)

All date-range queries extend the `to` boundary by +1 day for inclusive end:

```csharp
// TransactionRepository.GetTransactions:
var toInclusive = to.Date.AddDays(1);
// Uses: createdate >= p_from AND createdate < p_to  (open interval on right)
```

This pattern appears in: `GetTransactions`, `GetAllForExport`, `GetTotalByType`.

---

## Config Access Pattern

Runtime configuration lives in the `tbl_settings_config` table. Repositories read it through `IConfigRepository`:

```csharp
string GetString(string key, string defaultValue = "")
decimal GetDecimal(string key, decimal defaultValue = 0)
int GetInt(string key, int defaultValue = 0)
TimeSpan GetTimeSpan(string key, TimeSpan defaultValue)
List<string> GetStringList(string key, ...) // splits on comma
void SetString(string key, string value)    // direct UPDATE (no stored proc)
```

The underlying function:
```sql
spendmate_config_getvalue(p_key VARCHAR) → VARCHAR
-- SELECT ConfigValue FROM tbl_Settings_Config WHERE ConfigKey = p_key
```

---

## Repository → Stored Procedure Mapping

| Repository Method | Stored Procedure |
|---|---|
| `TransactionRepository.GetDailyTotal` | `spendmate_dashboard_getdailytotal(userid)` |
| `TransactionRepository.GetDailySummary` | `spendmate_dashboard_getdailysummary(userid)` |
| `TransactionRepository.GetTransactions` | `spendmate_transaction_getlist(userid, from, to)` |
| `TransactionRepository.GetById` | `spendmate_transaction_getbyid(id, userid)` |
| `TransactionRepository.Insert` | `spendmate_transaction_insert(userid, type, amount, category, destination, note, is_recurring, createdate)` |
| `TransactionRepository.Update` | `spendmate_transaction_update(id, userid, type, amount, category, destination, note, is_recurring, createdate)` |
| `TransactionRepository.Delete` | `spendmate_transaction_delete(id, userid)` |
| `TransactionRepository.GetAllForExport` | `spendmate_transaction_exportall(userid, from, to)` |
| `TransactionRepository.GetTotalByType` | `spendmate_transaction_gettotalbytype(userid, from, to, type)` |
| `DashboardRepository.GetTotal` | `spendmate_dashboard_getdailytotal(userid)` |
| `DashboardRepository.GetSummary` | `spendmate_dashboard_getdailysummary(userid)` |
| `DashboardRepository.Get6MonthTrend` | `spendmate_dashboard_get6monthtrend(userid)` |
| `BudgetRepository.GetMonthlyRecap` | `spendmate_budget_getmonthlyrecap(userid, year, month)` |
| `BudgetRepository.SaveBudget` | `spendmate_budget_save_monthly(userid, year, month, groupType, category, targetAmount, isPaid)` |
| `ReportRepository.GetReportData` | `spendmate_report_getdata(type, userid)` |
| `CategoryRepository.GetAll` | `spendmate_master_getcategories()` |
| `CategoryRepository.Save` | *(needs investigation — SP not confirmed in dump)* |
| `UserRepository.Authenticate` | `spendmate_user_getbyusername(username)` |
| `UserRepository.GetById` | `spendmate_user_getbyid(id)` |
| `UserRepository.GetAll` | `spendmate_user_getall()` |
| `UserRepository.Create` | `spendmate_user_insert(name, phonenumber, username, passwordhash)` |
| `UserRepository.Update` | `spendmate_user_update(id, name, phonenumber, username, passwordhash)` |
| `UserRepository.Delete` | `spendmate_user_delete(id)` |
| `ConfigRepository.GetString` | `spendmate_config_getvalue(key)` |
| `ConfigRepository.SetString` | Direct `UPDATE tbl_settings_config` (no SP) |
| Scheduler recurring | `spendmate_automation_runrecurring(userid)` |

---

## C# ↔ PostgreSQL Type Casting

Postgres requires explicit type casts in some cases. These are done in the Dapper SQL strings:
- `@FromDate::timestamp` — DateTime parameter cast to `timestamp without time zone`
- `@ToDate::timestamp` — same
- `@Type::VARCHAR` — string cast to `character varying`
- `@Key::VARCHAR` — for config key

If these casts are omitted, Npgsql may infer types incorrectly and throw a function signature mismatch error.
