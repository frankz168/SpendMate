using Microsoft.Extensions.Logging;
using System.Diagnostics;

public class DashboardService
{
    private readonly DashboardRepository _repo;
    private readonly ILogger<DashboardService> _logger;

    public DashboardService(
        DashboardRepository repo,
        ILogger<DashboardService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public DailySummaryVM GetDailySummary(int userId)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation("📊 Start GetDailySummary for UserId={UserId}", userId);

            var total = _repo.GetTotal(userId);
            var items = _repo.GetSummary(userId);

            sw.Stop();

            _logger.LogInformation(
                "✅ Dashboard loaded: Total={Total}, Items={Count}, Time={Ms}ms",
                total,
                items.Count,
                sw.ElapsedMilliseconds
            );

            return new DailySummaryVM
            {
                Total = total,
                Items = items
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Failed GetDailySummary for UserId={UserId}", userId);
            throw;
        }
    }
}