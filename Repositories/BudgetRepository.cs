using Dapper;
using SpendMate.Models;

public class BudgetRepository
{
    private readonly DbConnectionFactory _db;

    public BudgetRepository(DbConnectionFactory db)
    {
        _db = db;
    }

    public List<MonthlyBudget> GetMonthlyRecap(int userId, int year, int month)
    {
        using var conn = _db.CreateConnection();
        return conn.Query<MonthlyBudget>(
            "SELECT * FROM spendmate_budget_getmonthlyrecap(@UserId, @Year, @Month)",
            new { UserId = userId, Year = year, Month = month }
        ).ToList();
    }

    public void SaveBudget(int userId, int year, int month, string groupType, string category, decimal targetAmount, bool isPaid)
    {
        using var conn = _db.CreateConnection();
        conn.Execute(
            "SELECT spendmate_budget_save_monthly(@UserId, @Year, @Month, @GroupType, @Category, @TargetAmount, @IsPaid)",
            new { UserId = userId, Year = year, Month = month, GroupType = groupType, Category = category, TargetAmount = targetAmount, IsPaid = isPaid }
        );
    }
}
