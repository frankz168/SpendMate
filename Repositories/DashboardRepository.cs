using Dapper;

public class DashboardRepository
{
    private readonly DbConnectionFactory _db;

    public DashboardRepository(DbConnectionFactory db)
    {
        _db = db;
    }

    public decimal GetTotal(int userId)
    {
        using var conn = _db.CreateConnection();

        return conn.ExecuteScalar<decimal>(
            "SELECT get_daily_total(@UserId);",
            new { UserId = userId }
        );
    }

    public List<DailyItemVM> GetSummary(int userId)
    {
        using var conn = _db.CreateConnection();

        return conn.Query<DailyItemVM>(
            "SELECT * FROM get_daily_summary(@UserId);",
            new { UserId = userId }
        ).ToList();
    }
}