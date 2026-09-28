# SpendMate — Project Memory Vault

> **Vault created:** 2026-09-28  
> **Source authority:** The actual source code in `/Users/frankz168/SpendMate/` is always authoritative. This vault is a navigation and context layer.

---

## What is SpendMate?

SpendMate is a **personal household finance tracker** built for a single family (currently single-user: `UserId=1` hardcoded in several places). It runs as an ASP.NET Core MVC web application (.NET 10) backed by **PostgreSQL 18** via Dapper (no ORM, stored-procedure-only data access). Redis is used for caching. Gemini AI (Google) is integrated for two AI-powered features: smart natural-language transaction entry and monthly financial insight generation.

The application is deployed on a Mac (`/Users/frankz168/SpendMate/`) and runs on `http://0.0.0.0:5086`.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | .NET 10 / ASP.NET Core MVC |
| Database | PostgreSQL 18.3 (Homebrew) |
| DB Access | Dapper 2.1.72 + stored procedures only |
| Caching | Redis via StackExchange.Redis |
| AI | Google Gemini API (gemini-pro) |
| Email | MailKit 4.16.0 (Gmail SMTP) |
| Excel I/O | EPPlus 8.5.4 |
| Auth | Cookie authentication (30-day persistent) |
| Password | BCrypt.Net-Next 4.2.0 |
| Logging | Serilog (console + rolling daily file → `logs/spendmate.log`) |

---

## Repository Map

```
SpendMate/
├── Program.cs                    ← DI wiring, middleware pipeline
├── SpendMate.csproj              ← .NET 10, NuGet deps
├── appsettings.json              ← Base config (Kestrel on :5086)
├── appsettings.Development.json  ← DB conn strings, Redis, Gemini API key
│
├── Controllers/                  ← MVC controllers (all [Authorize] except Auth)
│   ├── BaseController.cs         ← GetUserId() helper (reads ClaimTypes.NameIdentifier)
│   ├── AuthController.cs         ← Login / Logout (cookie auth)
│   ├── DashboardController.cs
│   ├── TransactionController.cs  ← CRUD + SmartInput + ExportExcel + UploadBcaStatement
│   ├── BudgetController.cs       ← Monthly budget recap + ExportExcel
│   ├── InsightsController.cs     ← REST API: GET /api/insights/monthly
│   ├── ReportController.cs
│   ├── SettingsController.cs     ← Category CRUD + MonthlyBudget setting
│   ├── LogController.cs
│   ├── UserController.cs
│   └── HomeController.cs
│
├── Service/                      ← Business logic layer
│   ├── TransactionService.cs     ← Save/Delete/Export/UploadBcaStatement
│   ├── DashboardService.cs       ← Aggregates today + monthly + budget + trend; Redis cache
│   ├── ReportService.cs          ← Builds + emails HTML reports (daily/weekly/monthly)
│   ├── ReportSchedulerService.cs ← BackgroundService: polls every 1 min, fires reports + recurring
│   ├── FinancialInsightService.cs← Gemini AI monthly analysis; Redis cache 24h
│   ├── GeminiSmartInputService.cs← Gemini AI natural-language → Transaction JSON
│   ├── EmailService.cs           ← MailKit SMTP sender
│   └── RedisCacheService.cs      ← ICacheService wrapper over IDistributedCache
│
├── Repositories/                 ← Data-access layer (Dapper + stored procs)
│   ├── TransactionRepository.cs
│   ├── DashboardRepository.cs
│   ├── BudgetRepository.cs
│   ├── ReportRepository.cs
│   ├── CategoryRepository.cs
│   ├── ConfigRepository.cs       ← Key/value config from tbl_settings_config
│   └── UserRepository.cs
│
├── Interfaces/                   ← Contract interfaces for all repositories + services
├── Models/                       ← Plain domain models (Transaction, User, MonthlyBudget, Category, …)
├── ViewModels/                   ← DailySummaryVM, DailyItemVM
├── Data/
│   └── DbConnectionFactory.cs    ← Singleton; creates NpgsqlConnection per call
├── SQL/
│   ├── SpendMate.sql             ← Full pg_dump (canonical schema + seed data)
│   ├── migrate_v3_v4.sql … migrate_v13_user_sp.sql  ← Incremental migration scripts
│   └── update_recap_fn.sql, update_sp.sql, updated_functions*.sql
├── Views/                        ← Razor .cshtml views per controller
└── logs/                         ← Serilog output (spendmate-YYYYMMDD.log)
```

---

## Quick Navigation

| Question | Go to |
|---|---|
| How does auth work? | [`architecture/overview.md`](architecture/overview.md) → Auth section |
| How is a transaction saved? | [`flows/save-transaction.md`](flows/save-transaction.md) |
| How do scheduled reports work? | [`flows/scheduled-reports.md`](flows/scheduled-reports.md) |
| What are all the DB tables? | [`data/tables.md`](data/tables.md) |
| What stored procedures exist? | [`data/stored-procedures.md`](data/stored-procedures.md) |
| How does Redis caching work? | [`data/cache.md`](data/cache.md) |
| How does recurring automation work? | [`flows/recurring-automation.md`](flows/recurring-automation.md) |
| How does Gemini AI integration work? | [`components/gemini-integration.md`](components/gemini-integration.md) |
| What are the known risks? | [`invariants/system-invariants.md`](invariants/system-invariants.md) |
| Why stored procs instead of EF Core? | [`decisions/implementation-rationale.md`](decisions/implementation-rationale.md) |

---

## Configuration Keys (tbl_settings_config)

All runtime configuration lives in the database, read via `ConfigRepository`.

| Key | Default | Purpose |
|---|---|---|
| `MonthlyBudget` | `61260000` | Total monthly expense budget (IDR) |
| `Email_FromEmail` | gmail address | SMTP sender |
| `Email_Password` | app password | Gmail App Password |
| `Email_SmtpHost` | `smtp.gmail.com` | SMTP host |
| `Email_SmtpPort` | `587` | SMTP port |
| `Report_EmailTo` | two email addrs | Comma-separated report recipients |
| `Report_DailyTime` | `07:10:00` | Daily report fire time |
| `Report_WeeklyTime` | `07:10:00` | Weekly report fire time |
| `Report_MonthlyTime` | `07:10:00` | Monthly report fire time |
| `Report_WeeklyDay` | `0` (Sunday) | DayOfWeek for weekly report |
| `Report_MonthlyDay` | `1` | Day-of-month for monthly report |
