# Redis Cache

## Overview

Redis is used as a distributed cache for two high-cost read paths that aggregate multiple database queries into a single compound object. The cache is **non-critical** — all read paths have graceful fallbacks to the database on Redis failure.

---

## Connection

- **Host:** `localhost:6379` (dev)
- **Config string:** `localhost:6379,abortConnect=false`
  - `abortConnect=false` means the application starts successfully even if Redis is down
- **Instance prefix:** `SpendMate_` (prepended to all keys by the distributed cache framework)
- **Registered via:** `builder.Services.AddStackExchangeRedisCache(...)`

---

## Cache Entries

### 1. Dashboard Summary

| Property | Value |
|---|---|
| **Key pattern** | `SpendMate_Dashboard_Summary_{userId}_{yyyyMMdd_HH}` |
| **Example key** | `SpendMate_Dashboard_Summary_1_20260928_17` |
| **Type cached** | `DailySummaryVM` |
| **TTL** | 10 minutes (explicit) |
| **Set by** | `DashboardService.GetDailySummaryAsync()` |
| **Invalidation** | Natural expiry only; key changes every hour (HH portion) |

The hour-level granularity in the key means the cache naturally refreshes on the new hour, even before the 10-minute TTL. This causes up to ~60-minute stale data for a dashboard loaded early in the hour, but in practice the 10-minute TTL dominates.

**What it caches:**
- 6 `GetTotalByType` DB calls (today + monthly, three types)
- 1 `GetDecimal` config call
- 1 `GetReportData` call (monthly category breakdown)
- 1 `Get6MonthTrend` call

### 2. Financial Insights

| Property | Value |
|---|---|
| **Key pattern** | `SpendMate_FinancialInsights_Monthly_{userId}_{yyyyMM}` |
| **Example key** | `SpendMate_FinancialInsights_Monthly_1_202609` |
| **Type cached** | `FinancialInsightDto` |
| **TTL** | 24 hours |
| **Set by** | `FinancialInsightService.GetMonthlyInsightsAsync()` |
| **Invalidation** | Natural expiry only; key resets monthly (yyyyMM portion) |

The monthly key means the insight from, say, September 15 will be served until it expires (24h) even if September 28 data differs. This is an intentional tradeoff to avoid Gemini API cost per request.

---

## ICacheService Interface

```csharp
Task<T> GetAsync<T>(string key);
Task SetAsync<T>(string key, T value, TimeSpan? absoluteExpireTime = null);
Task RemoveAsync(string key);
```

**Default TTL:** 60 minutes when `absoluteExpireTime` is null.

**Serialization:** `System.Text.Json.JsonSerializer` — objects are serialized to JSON strings stored in Redis.

---

## RedisCacheService Error Handling

All three methods catch all exceptions silently:

```csharp
// GetAsync: returns default(T) on any error
// SetAsync: swallows error (object simply won't be cached)
// RemoveAsync: swallows error
```

`FinancialInsightService` additionally wraps both its Redis calls in `try-catch` with `LogWarning` to emit a user-facing warning log.

---

## Safe Mutation Guide

**Q: I need to add a new cached object. What do I do?**
1. Inject `ICacheService` into your service
2. Define a cache key pattern (prefix with domain, include userId and time scope)
3. Call `GetAsync<T>()` first; if non-null, return it
4. Compute the value from DB if cache miss
5. Call `SetAsync<T>(key, value, ttl)` — wrap in try-catch if you want graceful failure
6. Never rely on the cache for consistency-critical reads

**Q: I need to invalidate the dashboard cache after a transaction is saved.**
Currently there is **no active cache invalidation** — the cache expires naturally. To add invalidation after `TransactionService.Save()`:
1. Inject `ICacheService` into `TransactionService`
2. After `_repo.Insert/Update()`, call `_cache.RemoveAsync($"Dashboard_Summary_{model.UserId}_{DateTime.Now:yyyyMMdd_HH}")`
3. Note: this only removes the current-hour key; past keys will expire on their own

**Q: How do I clear all SpendMate cache in Redis?**
```bash
redis-cli -p 6379 KEYS "SpendMate_*" | xargs redis-cli DEL
```

---

## dump.rdb

There is a `dump.rdb` file in the project root (89 bytes — nearly empty). This is a Redis persistence file from when Redis was run with the project directory as its working directory. It is safe to ignore.
