# Database Tables

> **Authoritative source:** `SQL/SpendMate.sql` (full pg_dump) and incremental migration scripts in `SQL/`.  
> Database: `spendmate_db` on `localhost:5432`, owner: `frankz168`.

---

## Table: `transactions`

**Primary data store for all financial transactions.**

```sql
CREATE TABLE public.transactions (
    id          integer           NOT NULL,           -- PK, auto-increment (expenses_id_seq)
    userid      integer           NOT NULL,           -- FK → users.id
    amount      numeric(18,2)     NOT NULL,
    category    character varying(50) NOT NULL,       -- Free-text string (not FK to categories in practice)
    note        text,                                 -- Optional description
    createdate  timestamp without time zone DEFAULT now(),
    type        character varying(20) DEFAULT 'Expense' NOT NULL,  -- 'Income' | 'Expense' | 'Transfer'
    destination character varying(100),              -- Used for Transfer type
    is_recurring boolean          DEFAULT false       -- Added in v9 migration
);
```

**Indexes:**
- `idx_transactions_userid` on `(userid)`
- `idx_transactions_user_date` on `(userid, createdate)`
- `idx_transactions_createdate` on `(createdate)`

**FK:** `fk_user`: `transactions.userid → users.id`

**Key business rules:**
- `type` must be exactly `'Income'`, `'Expense'`, or `'Transfer'` (enforced at app layer, not DB constraint)
- `category` is a free-text string matching `categories.name` by convention, not enforced by FK
- `is_recurring = TRUE` marks a transaction as a template; the scheduler clones it monthly (sets `is_recurring = FALSE` on clones)
- Auto-recurring clones get note prefixed with `[Auto-Recurring] `
- `createdate` defaults to `NOW()` inside the insert stored procedure; the C# layer guards against `DateTime.MinValue` or year < 1970

**Date-range query note:** All range queries use `createdate >= p_from AND createdate < p_to` (exclusive right bound). C# adds `+1 day` to the `to` parameter to make it inclusive from the user's perspective.

---

## Table: `categories`

**Master list of spending/savings categories.**

```sql
CREATE TABLE public.categories (
    id             integer           NOT NULL,  -- PK, auto-increment
    name           character varying(100) NOT NULL UNIQUE,
    group_type     character varying(50) NOT NULL,  -- 'Fixed' | 'Savings' | 'Variable'
    default_target numeric(18,2)     DEFAULT 0 NOT NULL,  -- Default monthly budget amount
    is_active      boolean           DEFAULT true NOT NULL,
    createdate     timestamp without time zone DEFAULT now()
);
```

**Seeded data (from schema dump):**

| id | name | group_type | default_target |
|---|---|---|---|
| 1 | KPR HOME TENJO | Fixed | 6,300,000 |
| 2 | KPR HOME CRB | Fixed | 1,200,000 |
| 3 | GROCERIES MONTHLY | Fixed | 0 |
| 4 | ELECTRIC TOKEN | Fixed | 500,000 |
| 5 | PDAM | Fixed | 115,800 |
| 6 | TRANSPORT / GAS | Fixed | 150,000 |
| 7 | FRANKY PARENTS | Fixed | 0 |
| 8 | EVE PARENTS | Fixed | 4,000,000 |
| 9 | INTERNET & KUOTA | Fixed | 457,000 |
| 10 | LAUNDRY | Fixed | 35,000 |
| 11 | NANOVEST | Savings | 5,000,000 |
| 12 | GOLD 5GR | Savings | 12,071,625 |
| 13 | SILVER 100GR | Savings | 6,048,000 |
| 14 | DINING OUT | Variable | 0 |
| 15 | RECREATION | Variable | 0 |
| 16 | SHOPPING | Variable | 0 |
| 17 | OTHERS | Variable | 0 |

**Note:** Categories like `SHOPPING`, `OTHERS`, `Credit Card Statement` appear in `transactions.category` but may not have corresponding FK-linked rows (category matching is by name string equality, not FK).

---

## Table: `monthly_budgets`

**Stores per-user, per-month budget targets and payment status for each category.**

```sql
CREATE TABLE public.monthly_budgets (
    id            integer         NOT NULL,   -- PK
    userid        integer         NOT NULL,
    year          integer         NOT NULL,
    month         integer         NOT NULL,
    category_id   integer         NOT NULL,   -- FK → categories.id
    target_amount numeric(18,2)   DEFAULT 0 NOT NULL,
    is_paid       boolean         DEFAULT false NOT NULL
);
```

**Unique constraint:** `(userid, year, month, category_id)` — one row per user per month per category.

**FK:** `monthly_budgets.category_id → categories.id`

**`is_paid` semantics:** A manual flag that indicates the user has already made this payment. In the Excel export, paid rows are highlighted yellow. It does not affect financial calculations — `actual_amount` comes from actual `transactions` entries.

**Budget upsert pattern:** `spendmate_budget_save_monthly` does INSERT … ON CONFLICT (userid, year, month, category_id) DO UPDATE. It also auto-creates the category in `categories` if it doesn't exist (allows adding new categories from the budget UI).

---

## Table: `users`

**Application user accounts.**

```sql
CREATE TABLE public.users (
    id            integer           NOT NULL,   -- PK
    name          character varying(100),
    phonenumber   character varying(20) NOT NULL,
    createdate    timestamp without time zone DEFAULT now(),
    username      character varying(50) UNIQUE,
    password_hash character varying(255)          -- BCrypt hash
);
```

**Note:** `name` and `username` are nullable by DB definition, but the application treats them as required in the `User` model.

**Single-user reality:** Currently only `userId = 1` is actively used. The scheduler hardcodes `spendmate_automation_runrecurring(1)`.

---

## Table: `tbl_settings_config`

**Key-value runtime configuration store.**

```sql
CREATE TABLE public.tbl_settings_config (
    configkey   character varying(100) NOT NULL,  -- PK
    configvalue character varying(255) NOT NULL,
    description text,
    creator     character varying(100) DEFAULT 'System',
    createdate  timestamp without time zone DEFAULT now(),
    auditor     character varying(100),
    auditdate   timestamp without time zone
);
```

**All active configuration keys:** See [`project.md`](../project.md#configuration-keys-tbl_settings_config) for the full table.

**Access pattern:** Read-only via `spendmate_config_getvalue(key)`. Written via direct `UPDATE` in `ConfigRepository.SetString()` (no stored proc for writes). Audit fields (`auditor`, `auditdate`) are not populated by the application.

---

## Sequences (Auto-Increment)

| Sequence | Table | Column |
|---|---|---|
| `users_id_seq` | `users` | `id` |
| `expenses_id_seq` | `transactions` | `id` |
| `monthly_budgets_id_seq` | `monthly_budgets` | `id` |
| `categories_id_seq` | `categories` | `id` |

Note: The sequence for `transactions` is named `expenses_id_seq` (historical naming from when the table was called `expenses`).
