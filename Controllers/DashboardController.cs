using Dapper;
using Microsoft.AspNetCore.Mvc;

public class DashboardController : Controller
{
    private readonly DbConnectionFactory _db;

    public DashboardController(DbConnectionFactory db)
    {
        _db = db;
    }

    public IActionResult Index()
    {
        using var conn = _db.CreateConnection();

        var total = conn.ExecuteScalar<decimal>(
            "SELECT get_daily_total(@UserId);",
            new { UserId = 1 }
        );

        var items = conn.Query<DailyItemVM>(
            "SELECT * FROM get_daily_summary(@UserId);",
            new { UserId = 1 }
        ).ToList();

        var vm = new DailySummaryVM
        {
            Total = total,
            Items = items
        };

        return View(vm);
    }
}