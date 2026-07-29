using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Dapper;

public class ReportSchedulerService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<ReportSchedulerService> _logger;

    private DateTime _lastDailyRun = DateTime.MinValue;
    private DateTime _lastWeeklyRun = DateTime.MinValue;
    private DateTime _lastMonthlyRun = DateTime.MinValue;
    private DateTime _lastRecurringRun = DateTime.MinValue;

    public ReportSchedulerService(
        IServiceProvider serviceProvider,
        ILogger<ReportSchedulerService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("🚀 Scheduler STARTED");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var now = DateTime.Now;

                _logger.LogInformation("⏱ Tick: {Time}", now);

                using var scope = _serviceProvider.CreateScope();
                var reportService = scope.ServiceProvider.GetRequiredService<ReportService>();
                var config = scope.ServiceProvider.GetRequiredService<ConfigRepository>();

                CheckDaily(reportService, config, now);
                CheckWeekly(reportService, config, now);
                CheckMonthly(reportService, config, now);

                // Run recurring transaction automation
                CheckRecurring(scope.ServiceProvider, config, now);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "❌ Scheduler ERROR");
            }

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }

        _logger.LogInformation("🛑 Scheduler STOPPED");
    }

    // ================= DAILY
    private void CheckDaily(ReportService service, ConfigRepository config, DateTime now)
    {
        var time = config.GetTimeSpan("Report_DailyTime", new TimeSpan(7, 10, 0));
        var target = now.Date.Add(time);

        if (IsWithinOneMinute(now, target) &&
            _lastDailyRun.Date != now.Date)
        {
            _logger.LogInformation("🔥 Sending DAILY report...");

            service.SendReport("daily");

            _lastDailyRun = now;

            _logger.LogInformation("✅ DAILY report sent");
        }
    }

    // ================= WEEKLY
    private void CheckWeekly(ReportService service, ConfigRepository config, DateTime now)
    {
        var time = config.GetTimeSpan("Report_WeeklyTime", new TimeSpan(7, 10, 0));
        var target = now.Date.Add(time);
        
        int configDay = config.GetInt("Report_WeeklyDay", 0);
        DayOfWeek targetDay = (DayOfWeek)configDay;

        if (now.DayOfWeek == targetDay &&
            IsWithinOneMinute(now, target) &&
            _lastWeeklyRun.Date != now.Date)
        {
            _logger.LogInformation("🔥 Sending WEEKLY report...");

            service.SendReport("weekly");

            _lastWeeklyRun = now;

            _logger.LogInformation("✅ WEEKLY report sent");
        }
    }

    // ================= MONTHLY
    private void CheckMonthly(ReportService service, ConfigRepository config, DateTime now)
    {
        var time = config.GetTimeSpan("Report_MonthlyTime", new TimeSpan(7, 10, 0));
        var target = now.Date.Add(time);

        int targetDay = config.GetInt("Report_MonthlyDay", 1);

        if (now.Day == targetDay &&
            IsWithinOneMinute(now, target) &&
            _lastMonthlyRun.Date != now.Date)
        {
            _logger.LogInformation("🔥 Sending MONTHLY report...");

            service.SendReport("monthly");

            _lastMonthlyRun = now;

            _logger.LogInformation("✅ MONTHLY report sent");
        }
    }

    // ================= RECURRING AUTOMATION
    private void CheckRecurring(IServiceProvider serviceProvider, ConfigRepository config, DateTime now)
    {
        // Run it around 10:00 AM every day
        var time = new TimeSpan(10, 0, 0);
        var target = now.Date.Add(time);

        if (IsWithinOneMinute(now, target) &&
            _lastRecurringRun.Date != now.Date)
        {
            _logger.LogInformation("🔥 Running RECURRING transaction automation...");

            var db = serviceProvider.GetRequiredService<DbConnectionFactory>();
            using var conn = db.CreateConnection();
            
            // Assuming UserId 1 since it's hardcoded for now, but in a real app we'd loop users
            conn.Execute("SELECT spendmate_automation_runrecurring(1);");

            _lastRecurringRun = now;

            _logger.LogInformation("✅ RECURRING automation completed");
        }
    }

    // ================= HELPER
    private bool IsWithinOneMinute(DateTime now, DateTime target)
    {
        return Math.Abs((now - target).TotalSeconds) < 60;
    }
}