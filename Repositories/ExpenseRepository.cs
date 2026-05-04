using Dapper;
using System.Data;

public class ExpenseRepository
{
    private readonly DbConnectionFactory _db;

    public ExpenseRepository(DbConnectionFactory db)
    {
        _db = db;
    }

    public decimal GetDailyTotal(int userId)
    {
        using var conn = _db.CreateConnection();

        return conn.ExecuteScalar<decimal>(
            "SELECT get_daily_total(@UserId);",
            new { UserId = userId }
        );
    }

    public IEnumerable<dynamic> GetDailySummary(int userId)
    {
        using var conn = _db.CreateConnection();

        return conn.Query(
            "SELECT * FROM get_daily_summary(@UserId);",
            new { UserId = userId }
        );
    }

    public IEnumerable<Expense> GetTodayExpenses(int userId)
    {
        using var conn = _db.CreateConnection();

        return conn.Query<Expense>(@"
            SELECT id, amount, category, note, createdate
            FROM expenses
            WHERE userid = @UserId
              AND createdate >= CURRENT_DATE
              AND createdate < CURRENT_DATE + INTERVAL '1 day'
            ORDER BY createdate DESC",
            new { UserId = userId });
    }

    public Expense GetById(int id, int userId)
    {
        using var conn = _db.CreateConnection();

        return conn.QueryFirstOrDefault<Expense>(@"
            SELECT id, amount, category, note
            FROM expenses
            WHERE id = @id AND userid = @UserId",
            new { id, UserId = userId });
    }

    public void Insert(Expense model)
    {
        using var conn = _db.CreateConnection();

        conn.Execute(@"
            INSERT INTO expenses(userid, amount, category, note, createdate)
            VALUES (@UserId, @Amount, @Category, @Note, NOW())",
            model);
    }

    public void Update(Expense model)
    {
        using var conn = _db.CreateConnection();

        conn.Execute(@"
            UPDATE expenses
            SET amount = @Amount,
                category = @Category,
                note = @Note
            WHERE id = @Id AND userid = @UserId",
            model);
    }

    public void Delete(int id, int userId)
    {
        using var conn = _db.CreateConnection();

        conn.Execute(@"
            DELETE FROM expenses 
            WHERE id = @id AND userid = @UserId",
            new { id, UserId = userId });
    }

    public IEnumerable<dynamic> GetAllForExport(int userId)
    {
        using var conn = _db.CreateConnection();

        return conn.Query(@"
            SELECT createdate, category, amount, note
            FROM expenses
            WHERE userid = @UserId
            ORDER BY createdate DESC",
            new { UserId = userId });
    }
}