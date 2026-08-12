using Dapper;
using Microsoft.Extensions.Logging;

public class ReportRepository : IReportRepository
{
    private readonly DbConnectionFactory _db;
    private readonly ILogger<ReportRepository> _logger;

    public ReportRepository(
        DbConnectionFactory db,
        ILogger<ReportRepository> logger)
    {
        _db = db;
        _logger = logger;
    }

    public List<ReportItem> GetReportData(string type, int userId)
    {
        try
        {
            _logger.LogInformation("🧾 [Repo] GetReportData START: {Type}", type);

            using var conn = _db.CreateConnection();

            var sql = "SELECT * FROM spendmate_report_getdata(@Type::VARCHAR, @UserId);";
            
            var result = conn.Query<ReportItem>(sql, new { Type = type, UserId = userId }).ToList();

            _logger.LogInformation(
                "📦 [Repo] GetReportData DONE: {Type}, Count={Count}",
                type,
                result.Count);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ [Repo] GetReportData FAILED: {Type}", type);
            throw;
        }
    }
}