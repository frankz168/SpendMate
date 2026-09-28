# Scheduled Reports Flow

## What Gets Sent

Three report cadences are supported: **daily**, **weekly**, **monthly**. All send the same HTML email template but with different date ranges.

---

## Schedule Configuration

All schedule settings live in `tbl_settings_config`:

| Config Key | Default | Meaning |
|---|---|---|
| `Report_DailyTime` | `07:10:00` | Time of day for daily report |
| `Report_WeeklyTime` | `07:10:00` | Time of day for weekly report |
| `Report_WeeklyDay` | `0` (Sunday) | DayOfWeek for weekly report |
| `Report_MonthlyTime` | `07:10:00` | Time of day for monthly report |
| `Report_MonthlyDay` | `1` | Day of month for monthly report |
| `Report_EmailTo` | two addresses | Comma-separated recipients |

---

## Trigger Mechanism

`ReportSchedulerService` polls every 1 minute. For each cadence:

```
now.Date matches target day?   (weekly: DayOfWeek; monthly: day-of-month)
AND IsWithinOneMinute(now, target)?  (|now - targetTime| < 60 seconds)
AND _lastXxxRun.Date != now.Date?   (haven't already sent today)
→ fire
```

`IsWithinOneMinute` uses `Math.Abs((now - target).TotalSeconds) < 60`.

---

## Date Ranges Per Report Type

| Type | `from` | `to` |
|---|---|---|
| `daily` | `now.Date` (midnight today) | `now` |
| `weekly` | Monday of current week | `now` |
| `monthly` | 1st day of current month | `now` |

Weekly `from` calculation:
```csharp
int diff = (7 + (now.DayOfWeek - DayOfWeek.Monday)) % 7;
from = now.AddDays(-diff).Date;
```

---

## Report Content

Built by `ReportService.BuildTemplate()`:

```
💼 SpendMate Report
📊 {DAILY|WEEKLY|MONTHLY} Summary

Total Expenses: Rp{total}
Budget (Monthly): Rp{budget}
📆 Day: {dayNow} / {daysInMonth}

[Status section]:
  If over budget: ❌ Over budget: Rp{|remaining|}  (red)
  If under budget: ✅ Remaining budget: Rp{remaining}  (green)
  Used: {percent}%
  💡 Tip text

📌 Expense Breakdown:
  • {Category}: Rp{amount}   (per category, all in period)

🔥 Top spending category: {topCategory}
```

**Category icons** (in email only): Food→🍽️, Transport→🚗, Shopping→🛍️, others→📦.

---

## Email Delivery

```csharp
var emails = _config.GetStringList("Report_EmailTo");  // splits on comma
foreach (var email in emails)
    _email.Send(email, "💼 SpendMate {TYPE} Report", html);
```

Subject format: `"💼 SpendMate DAILY Report"`, `"💼 SpendMate WEEKLY Report"`, etc.

---

## Related Code

| Symbol | File |
|---|---|
| `ReportSchedulerService` | [`Service/ReportSchedulerService.cs`](file:///Users/frankz168/SpendMate/Service/ReportSchedulerService.cs) |
| `ReportService` | [`Service/ReportService.cs`](file:///Users/frankz168/SpendMate/Service/ReportService.cs) |
| `EmailService` | [`Service/EmailService.cs`](file:///Users/frankz168/SpendMate/Service/EmailService.cs) |
| `ReportRepository` | [`Repositories/ReportRepository.cs`](file:///Users/frankz168/SpendMate/Repositories/ReportRepository.cs) |
| `ReportController` | [`Controllers/ReportController.cs`](file:///Users/frankz168/SpendMate/Controllers/ReportController.cs) |
