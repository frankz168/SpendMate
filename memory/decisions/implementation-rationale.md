# Implementation Rationale

> This document records architectural decisions, their context, and their consequences. Understanding *why* decisions were made prevents accidental reversals.

---

## DEC-001: Dapper + Stored Procedures Instead of Entity Framework Core

**Decision:** All database access uses Dapper with PostgreSQL stored functions. No ORM (EF Core) is used despite the project file including `Npgsql.EntityFrameworkCore.PostgreSQL`.

**Context:** The project targets a single-user personal finance app where:
- SQL logic needs to be explicit and reviewable
- Complex aggregations (6-month trend, budget recap with multiple CTEs) are easier to write and maintain in SQL
- Performance predictability is important — no N+1 surprise queries

**Consequences:**
- All DB logic is versionable as SQL files in `SQL/`
- Schema changes require explicit migration scripts (no `dotnet ef migrations add`)
- No lazy loading — all data access is explicit
- Dapper's dynamic mapping requires careful column name matching (case-sensitive for quoted identifiers)
- `Npgsql.EntityFrameworkCore.PostgreSQL` in `.csproj` appears to be unused (included but not configured via `AddDbContext`)

**Safe-change rule:** Do not introduce `AddDbContext` or `DbContext` without a deliberate decision to migrate. The two approaches (Dapper + SP vs EF Core) should not be mixed in the same project without a clear boundary.

---

## DEC-002: Cookie Authentication with 30-Day Persistent Sessions

**Decision:** Authentication uses ASP.NET Core cookie middleware with 30-day persistent cookies.

**Context:** Personal household app used by known family members on personal devices. Convenience (no re-login for a month) outweighed security strictness.

**Consequences:**
- No session store needed
- Password change does not invalidate existing sessions
- A stolen cookie is valid for up to 30 days
- No `[ValidateAntiForgeryToken]` is consistently applied (needs audit)

---

## DEC-003: In-Memory Scheduler with 1-Minute Poll

**Decision:** `ReportSchedulerService` uses a 1-minute `Task.Delay` loop with in-memory tracking of last-run timestamps instead of a proper cron library (like Quartz.NET) or database-backed scheduler.

**Context:** The app runs on a single machine. Simplicity was prioritized over reliability.

**Consequences:**
- App restarts lose last-run state → potential double-sends or missed sends in a crash window
- 1-minute polling resolution means reports fire within ±1 minute of their scheduled time (acceptable for personal use)
- Adding a new scheduled job requires modifying `ReportSchedulerService.ExecuteAsync()` and adding a new field + method

**Alternative considered:** A cron library or Hangfire would provide persistence and better scheduling primitives, but adds complexity not warranted for a single-user app.

---

## DEC-004: Redis for Dashboard Caching (not in-process memory cache)

**Decision:** Dashboard aggregation results are cached in Redis (`IDistributedCache`) rather than `IMemoryCache`.

**Context:** Although the app is single-instance, using `IDistributedCache` was chosen to:
- Allow future horizontal scaling
- Keep the caching abstraction decoupled (`ICacheService` interface)
- Leverage the existing Redis instance (already needed for potential session storage or other uses)

**Consequences:**
- Redis must be running for the cache to work (but `abortConnect=false` means app works without it)
- Serialization overhead (JSON serialize/deserialize on every cache hit)
- Key management is manual (no automatic cache invalidation on data write)

---

## DEC-005: AI Financial Features via Gemini API (not local model)

**Decision:** Both the Smart Transaction Input and the Financial Insights features call the Google Gemini API over HTTPS.

**Context:** Local LLM inference was not practical for a personal app on a Mac. Gemini API provides sufficient quality for the prompts used.

**Consequences:**
- Requires internet connectivity to use these features
- API key must be maintained in `appsettings.Development.json` (not committed to git — verify `.gitignore`)
- Gemini model version is pinned to `gemini-pro` in the endpoint URL; model upgrades require config change
- Financial data (category summaries, transaction notes) is sent to Google's servers — privacy consideration for sensitive transactions

**Failure handling:**
- Smart Input: fails hard → user sees error message (forced retry)
- Financial Insights: graceful degradation → returns a static fallback message

---

## DEC-006: BCA Statement Import via EPPlus (no banking API)

**Decision:** Bank transactions are imported by uploading the eStatement file (CSV or Excel) downloaded from BCA internet banking, rather than a direct banking API integration.

**Context:** BCA does not offer a consumer-facing open banking API. The eStatement file format is the only practical bulk import method.

**Consequences:**
- Import relies on the BCA statement column layout (columns 1, 2, 4, 5) which could change
- Category assignment is keyword-based (hardcoded in `TransactionService.UploadBcaStatement`) — brittle
- EPPlus non-commercial license must be maintained
- Debug `Console.WriteLine` statements remain in this code path

---

## DEC-007: Single-User Design with Hardcoded UserId=1

**Decision:** The system was built for a single household and hardcodes `UserId=1` in several places rather than implementing full multi-user data isolation from the start.

**Context:** The system serves one user (or one household sharing an account). Full multi-user design was considered premature optimization.

**Consequences:**
- `Transaction.UserId = 1` default means forms that don't pass UserId in the request body silently use userId=1
- Scheduler fires reports and recurring automation for userId=1 only
- Adding a second real user requires fixing ~5 hardcoded references (see INV-002)

---

## DEC-008: All Configuration in Database (`tbl_settings_config`)

**Decision:** Report schedules, email addresses, SMTP credentials, and budget targets live in `tbl_settings_config` rather than `appsettings.json`.

**Context:** These values need to be changeable at runtime without redeployment. The `SettingsController` allows updating the `MonthlyBudget` via the UI.

**Consequences:**
- Configuration reads hit the database on every scheduler tick (no caching of config values)
- Changing a schedule requires a direct DB update (no UI for schedule config — only budget and category management)
- Sensitive values (email password) are stored in plaintext in the database
- `appsettings.Development.json` holds connection strings and API keys (not in DB, not committed to git — verify)
