# Recurring Transaction Automation Flow

## Concept

A user can mark any transaction as a "recurring template" by setting `IsRecurring = true`. The scheduler automatically creates a copy of that transaction at the start of each month (clone has `is_recurring = false`, so it counts as a normal transaction).

---

## How to Create a Recurring Template

1. Create or edit any transaction in the UI
2. Check the "Recurring" checkbox
3. Save → `is_recurring = TRUE` stored in DB
4. The scheduler will clone it on the 1st of each following month

---

## Automation Trigger

```
ReportSchedulerService.CheckRecurring()
→ Fires daily at 10:00 AM (hardcoded TimeSpan(10, 0, 0))
→ Guard: _lastRecurringRun.Date != now.Date (once per day)
→ conn.Execute("SELECT spendmate_automation_runrecurring(1);")
```

---

## Stored Procedure Logic (`spendmate_automation_runrecurring`)

```sql
DECLARE v_start_of_month DATE = date_trunc('month', CURRENT_DATE)::date;

FOR rec IN
    SELECT * FROM transactions
    WHERE userid = p_userid
      AND is_recurring = TRUE
      -- Template must be from a prior month (not this month)
      AND date_trunc('month', createdate)::date < v_start_of_month
LOOP
    -- Check if clone already exists this month
    IF NOT EXISTS (
        SELECT 1 FROM transactions
        WHERE userid = p_userid
          AND category = rec.category
          AND amount = rec.amount
          AND type = rec.type
          AND note LIKE '[Auto-Recurring]%'
          AND is_recurring = FALSE
          AND date_trunc('month', createdate)::date = v_start_of_month
    ) THEN
        INSERT INTO transactions (userid, type, amount, category, destination, note, createdate, is_recurring)
        VALUES (rec.userid, rec.type, rec.amount, rec.category, rec.destination,
                '[Auto-Recurring] ' || COALESCE(rec.note, ''), CURRENT_DATE, FALSE);
    END IF;
END LOOP;
```

---

## Key Behaviors

| Behavior | Detail |
|---|---|
| **Idempotent** | Running it twice in a month produces at most 1 clone per template |
| **Date of clone** | `CURRENT_DATE` (day the automation runs — typically 1st of month) |
| **Note prefix** | `[Auto-Recurring] ` prepended to original note |
| **Template excluded from cloning in its creation month** | `date_trunc('month', createdate) < v_start_of_month` guard |
| **Collision detection** | Matches on category + amount + type + note prefix + this month |
| **UserId** | Hardcoded to `1` in the scheduler call |

---

## Edge Cases

**What if the app was down on the 1st?**
The automation fires every day at 10:00 AM. If it was down on the 1st but runs on the 2nd, the clone is created with `createdate = 2nd of month`. This is correct behavior — better late than never.

**What if a user manually creates a transaction that matches the collision criteria?**
The automation will skip the clone (thinks it already exists). The user would need to either rename the note or wait for the automation to not match. This is an edge case for personal use.

**What if `is_recurring = TRUE` and the template was created this month?**
The `date_trunc('month', createdate) < v_start_of_month` guard prevents same-month templates from being cloned in the same month they were created. They will be cloned in all subsequent months.

---

## Related Code

| Symbol | File |
|---|---|
| `ReportSchedulerService.CheckRecurring` | [`Service/ReportSchedulerService.cs`](file:///Users/frankz168/SpendMate/Service/ReportSchedulerService.cs#L122-L144) |
| `spendmate_automation_runrecurring` | [`SQL/SpendMate.sql`](file:///Users/frankz168/SpendMate/SQL/SpendMate.sql#L68-L110) |
| `migrate_v9_recurring.sql` | [`SQL/migrate_v9_recurring.sql`](file:///Users/frankz168/SpendMate/SQL/migrate_v9_recurring.sql) |
| `Transaction.IsRecurring` | [`Models/Transaction.cs`](file:///Users/frankz168/SpendMate/Models/Transaction.cs) |
