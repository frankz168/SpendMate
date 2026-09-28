# Save Transaction Flow

## Entry Points

| Trigger | HTTP | Controller Action |
|---|---|---|
| Manual form | POST /Transaction/Save | `TransactionController.Save` |
| After Gemini Smart Input review | POST /Transaction/Save | same |
| Edit existing | POST /Transaction/Save (Id ≠ 0) | same |

---

## Full Stack Trace

```
POST /Transaction/Save
  Body: { Id, UserId, Type, Amount, Category, Destination, Note, Createdate, IsRecurring }

TransactionController.Save([FromBody] Transaction model)
  model.UserId = GetUserId()  // always override from auth claims
  _service.Save(model)

TransactionService.Save(model)
  Stopwatch starts, logs "💾 Save START"
  // Date guard:
  if (model.Createdate == default || Createdate <= DateTime.MinValue || Createdate.Year < 1970)
      model.Createdate = DateTime.Now

  if (model.Id == 0)
      _repo.Insert(model)   → spendmate_transaction_insert(...)
  else
      _repo.Update(model)   → spendmate_transaction_update(...)

  Logs "✅ Save SUCCESS"
  return OK()
```

---

## Insert vs Update Routing

| `model.Id` | Action |
|---|---|
| `0` | Insert (new transaction) |
| `> 0` | Update (existing transaction) |

**Insert** returns new DB id (via RETURNING id) but C# ignores the return value in `Save()` path.

**Update** scopes to `WHERE id = p_id AND userid = p_userid` — user cannot update another user's transaction.

---

## After Save — Cache Consideration

Currently, saving a transaction does **NOT** invalidate the Redis dashboard cache. The cache expires naturally (10-minute TTL). This means:

- A newly saved transaction will NOT appear on the dashboard for up to 10 minutes
- A deleted transaction will remain in dashboard totals for up to 10 minutes

If real-time dashboard accuracy is needed after a save, add cache invalidation to `TransactionService.Save()` and `Delete()`.

---

## Related Code

| Symbol | File |
|---|---|
| `TransactionController.Save` | [`Controllers/TransactionController.cs`](file:///Users/frankz168/SpendMate/Controllers/TransactionController.cs#L53-L59) |
| `TransactionService.Save` | [`Service/TransactionService.cs`](file:///Users/frankz168/SpendMate/Service/TransactionService.cs#L75-L115) |
| `TransactionRepository.Insert` | [`Repositories/TransactionRepository.cs`](file:///Users/frankz168/SpendMate/Repositories/TransactionRepository.cs#L139-L173) |
| `TransactionRepository.Update` | [`Repositories/TransactionRepository.cs`](file:///Users/frankz168/SpendMate/Repositories/TransactionRepository.cs#L176-L211) |
