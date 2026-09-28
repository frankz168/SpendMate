# Architecture Overview

## Application Style

SpendMate is a **server-rendered MVC web application** (no SPA frontend framework). Razor views are returned for all UI pages. There is one REST API endpoint (`GET /api/insights/monthly`) consumed by client-side JavaScript on the dashboard.

---

## Layered Architecture

```
Browser / HTTP Client
        │
        ▼
┌──────────────────────────────────┐
│         Controllers (MVC)        │  ← HTTP boundary, auth guard, route dispatch
│  AuthController, TransactionCtrl │
│  BudgetController, InsightsCtrl  │
│  DashboardController, …          │
└──────────────────────────────────┘
        │ calls
        ▼
┌──────────────────────────────────┐
│          Service Layer           │  ← Business logic, orchestration, Gemini calls
│  TransactionService              │
│  DashboardService                │
│  ReportService                   │
│  FinancialInsightService         │
│  GeminiSmartInputService         │
│  EmailService                    │
│  RedisCacheService               │
└──────────────────────────────────┘
        │ calls
        ▼
┌──────────────────────────────────┐
│        Repository Layer          │  ← Dapper + stored-procedure calls, no raw SQL in services
│  TransactionRepository           │
│  DashboardRepository             │
│  BudgetRepository                │
│  ReportRepository                │
│  CategoryRepository              │
│  ConfigRepository                │
│  UserRepository                  │
└──────────────────────────────────┘
        │ uses
        ▼
┌──────────────────────────────────┐
│       DbConnectionFactory        │  ← Singleton; NpgsqlConnection per call
│  (Data/DbConnectionFactory.cs)   │
└──────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────┐
│    PostgreSQL 18 (localhost:5432) │
│    Database: spendmate_db        │
│    All access via stored procs   │
└──────────────────────────────────┘

Sidecars:
  Redis (localhost:6379)  ← DashboardService + FinancialInsightService caching
  Gemini API (HTTPS)      ← GeminiSmartInputService + FinancialInsightService
  Gmail SMTP (:587)       ← EmailService → ReportService
```

---

## Authentication

- **Scheme:** Cookie authentication (`CookieAuthenticationDefaults`)
- **Login path:** `GET/POST /Auth/Login`
- **Logout path:** `GET /Auth/Logout`
- **Cookie lifetime:** 30 days (persistent)
- **Claims stored:** `ClaimTypes.NameIdentifier` (user ID), `ClaimTypes.Name` (display name), `"Username"` (username)
- **Password hashing:** BCrypt (BCrypt.Net-Next 4.2.0)
- **All controllers** extend `BaseController` and are `[Authorize]` except `AuthController` itself
- `BaseController.GetUserId()` reads `ClaimTypes.NameIdentifier` from the claims principal

**Auth flow:**
1. `AuthController.Login(POST)` → `UserRepository.Authenticate(username, password)`
2. Repo fetches user by username via `spendmate_user_getbyusername` SP
3. BCrypt.Verify against stored hash
4. On success: `HttpContext.SignInAsync(...)` with claims principal, 30-day expiry
5. Redirect to `Dashboard/Index`

---

## Background Services

`ReportSchedulerService` is registered as a `IHostedService` (`BackgroundService`). It:
- Runs an infinite loop checking every **1 minute**
- Checks and fires: daily, weekly, monthly email reports
- Checks and fires: recurring transaction automation (daily at 10:00 AM)
- Uses `IsWithinOneMinute()` guard + per-cycle last-run tracking to avoid double-fires
- Obtains scoped services by creating a new `IServiceProvider` scope per tick (avoids singleton-scoped service lifetime issues)

---

## Dependency Injection Registration (Program.cs)

| Service | Lifetime | Interface |
|---|---|---|
| `DbConnectionFactory` | Singleton | — |
| `ConfigRepository` | Scoped | `IConfigRepository` |
| `DashboardRepository` | Scoped | `IDashboardRepository` |
| `DashboardService` | Scoped | — |
| `UserRepository` | Scoped | `IUserRepository` |
| `TransactionRepository` | Scoped | `ITransactionRepository` |
| `TransactionService` | Scoped | — |
| `BudgetRepository` | Scoped | `IBudgetRepository` |
| `CategoryRepository` | Scoped | `ICategoryRepository` |
| `EmailService` | Scoped | — |
| `ReportRepository` | Scoped | `IReportRepository` |
| `ReportService` | Scoped | — |
| `ReportSchedulerService` | Hosted (Singleton) | `IHostedService` |
| `RedisCacheService` | Scoped | `ICacheService` |
| `GeminiSmartInputService` | Scoped (HttpClient) | `IGeminiSmartInputService` |
| `FinancialInsightService` | Scoped (HttpClient) | `IFinancialInsightService` |

**Redis** is registered via `AddStackExchangeRedisCache` with instance prefix `SpendMate_`.

---

## HTTP Pipeline Order (Program.cs)

```
SerilogRequestLogging
→ ExceptionHandler (/Home/Error) [Production only]
→ HSTS [Production only]
→ HttpsRedirection
→ Routing
→ Authentication
→ Authorization
→ StaticAssets
→ MapControllerRoute (default: {controller=Home}/{action=Index}/{id?})
```

---

## Key Gotchas

1. **`UserId=1` hardcoded** — `Transaction.UserId` defaults to `1`. The scheduler also hardcodes `userId = 1` for recurring automation. This is a known single-user design limitation.
2. **`DbConnectionFactory` is Singleton** but creates a new connection each call (connection-per-operation pattern via `using var conn = _db.CreateConnection()`). Connections are opened and disposed per method call.
3. **`ReportSchedulerService` needs scoped services** — It creates a new DI scope on every tick to resolve `ReportService` and `IConfigRepository` (which are scoped).
4. **`spendmate_report_getdata`** in SQL does NOT filter by `userid` — this is a known data isolation bug (see [`invariants/system-invariants.md`](../invariants/system-invariants.md)).
