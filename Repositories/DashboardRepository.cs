using Dapper;
using Microsoft.Extensions.Logging;
using System.Diagnostics;

public class DashboardRepository : IDashboardRepository
{
    private readonly DbConnectionFactory _db;
    private readonly ILogger<DashboardRepository> _logger;

    public DashboardRepository(
        DbConnectionFactory db,
        ILogger<DashboardRepository> logger)
    {
        _db = db;
        _logger = logger;
    }

    public decimal GetTotal(int userId)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation(
                "📊 [Dashboard] GetTotal START | UserId={UserId}",
                userId);

            using var conn = _db.CreateConnection();

            var result = conn.ExecuteScalar<decimal>(
                "SELECT spendmate_dashboard_getdailytotal(@UserId);",
                new { UserId = userId }
            );

            sw.Stop();

            _logger.LogInformation(
                "✅ [Dashboard] GetTotal SUCCESS | Total={Total}, Duration={Ms}ms",
                result, sw.ElapsedMilliseconds);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "❌ [Dashboard] GetTotal FAILED | UserId={UserId}",
                userId);

            throw;
        }
    }

    public List<DailyItemVM> GetSummary(int userId)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation(
                "📊 [Dashboard] GetSummary START | UserId={UserId}",
                userId);

            using var conn = _db.CreateConnection();

            var result = conn.Query<DailyItemVM>(
                "SELECT * FROM spendmate_dashboard_getdailysummary(@UserId);",
                new { UserId = userId }
            ).ToList();

            sw.Stop();

            _logger.LogInformation(
                "✅ [Dashboard] GetSummary SUCCESS | Count={Count}, Duration={Ms}ms",
                result.Count, sw.ElapsedMilliseconds);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "❌ [Dashboard] GetSummary FAILED | UserId={UserId}",
                userId);

            throw;
        }
    }

    public List<SpendMate.Models.TrendItem> Get6MonthTrend(int userId)
    {
        using var conn = _db.CreateConnection();
        return conn.Query<SpendMate.Models.TrendItem>(
            "SELECT month, income, expense FROM spendmate_dashboard_get6monthtrend(@UserId);",
            new { UserId = userId }
        ).ToList();
    }
}