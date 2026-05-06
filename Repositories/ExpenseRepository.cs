using Dapper;
using Microsoft.Extensions.Logging;
using System.Data;
using System.Diagnostics;

public class ExpenseRepository
{
    private readonly DbConnectionFactory _db;
    private readonly ILogger<ExpenseRepository> _logger;

    public ExpenseRepository(
        DbConnectionFactory db,
        ILogger<ExpenseRepository> logger)
    {
        _db = db;
        _logger = logger;
    }

    public decimal GetDailyTotal(int userId)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            using var conn = _db.CreateConnection();

            var result = conn.ExecuteScalar<decimal>(
                "SELECT get_daily_total(@UserId);",
                new { UserId = userId }
            );

            sw.Stop();

            _logger.LogInformation(
                "GetDailyTotal | UserId={UserId}, Result={Result}, {Ms}ms",
                userId, result, sw.ElapsedMilliseconds);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "GetDailyTotal FAILED | UserId={UserId}",
                userId);
            throw;
        }
    }

    public IEnumerable<dynamic> GetDailySummary(int userId)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            using var conn = _db.CreateConnection();

            var data = conn.Query(
                "SELECT * FROM get_daily_summary(@UserId);",
                new { UserId = userId }
            ).ToList();

            sw.Stop();

            _logger.LogInformation(
                "GetDailySummary | UserId={UserId}, Count={Count}, {Ms}ms",
                userId, data.Count, sw.ElapsedMilliseconds);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "GetDailySummary FAILED | UserId={UserId}",
                userId);
            throw;
        }
    }

    public IEnumerable<Expense> GetExpenses(int userId, DateTime from, DateTime to)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            using var conn = _db.CreateConnection();

            var data = conn.Query<Expense>(@"
                SELECT id, amount, category, note, createdate
                FROM expenses
                WHERE userid = @UserId
                AND createdate >= @FromDate
                AND createdate < @ToDate
                ORDER BY createdate DESC",
                new
                {
                    UserId = userId,
                    FromDate = from,
                    ToDate = to
                }).ToList();

            sw.Stop();

            _logger.LogInformation(
                "GetExpenses | UserId={UserId}, Count={Count}, {Ms}ms",
                userId, data.Count, sw.ElapsedMilliseconds);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "GetExpenses FAILED | UserId={UserId}",
                userId);
            throw;
        }
    }

    public Expense GetById(int id, int userId)
    {
        try
        {
            using var conn = _db.CreateConnection();

            var data = conn.QueryFirstOrDefault<Expense>(@"
                SELECT id, amount, category, note, createdate
                FROM expenses
                WHERE id = @id AND userid = @UserId",
                new { id, UserId = userId });

            _logger.LogInformation(
                "GetById | Id={Id}, UserId={UserId}, Found={Found}",
                id, userId, data != null);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "GetById FAILED | Id={Id}, UserId={UserId}",
                id, userId);
            throw;
        }
    }

    public void Insert(Expense model)
    {
        try
        {
            using var conn = _db.CreateConnection();

            conn.Execute(@"
                INSERT INTO expenses(userid, amount, category, note, createdate)
                VALUES (@UserId, @Amount, @Category, @Note, NOW())",
                model);

            _logger.LogInformation(
                "Insert Expense | UserId={UserId}, Amount={Amount}, Category={Category}",
                model.UserId, model.Amount, model.Category);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Insert FAILED | UserId={UserId}",
                model.UserId);
            throw;
        }
    }

    public void Update(Expense model)
    {
        try
        {
            using var conn = _db.CreateConnection();

            conn.Execute(@"
                UPDATE expenses
                SET amount = @Amount,
                    category = @Category,
                    note = @Note
                WHERE id = @Id AND userid = @UserId",
                model);

            _logger.LogInformation(
                "Update Expense | Id={Id}, UserId={UserId}",
                model.Id, model.UserId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Update FAILED | Id={Id}",
                model.Id);
            throw;
        }
    }

    public void Delete(int id, int userId)
    {
        try
        {
            using var conn = _db.CreateConnection();

            conn.Execute(@"
                DELETE FROM expenses 
                WHERE id = @id AND userid = @UserId",
                new { id, UserId = userId });

            _logger.LogInformation(
                "Delete Expense | Id={Id}, UserId={UserId}",
                id, userId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Delete FAILED | Id={Id}",
                id);
            throw;
        }
    }

    public IEnumerable<dynamic> GetAllForExport(int userId, DateTime? from, DateTime? to)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            using var conn = _db.CreateConnection();

            var sql = @"
                SELECT createdate, category, amount, note
                FROM expenses
                WHERE userid = @UserId
            ";

            if (from.HasValue)
                sql += " AND createdate >= @FromDate";

            if (to.HasValue)
                sql += " AND createdate <= @ToDate";

            sql += " ORDER BY createdate DESC";

            var data = conn.Query(sql, new
            {
                UserId = userId,
                FromDate = from,
                ToDate = to
            }).ToList();

            sw.Stop();

            _logger.LogInformation(
                "Export Data | UserId={UserId}, Count={Count}, {Ms}ms",
                userId, data.Count, sw.ElapsedMilliseconds);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Export FAILED | UserId={UserId}",
                userId);
            throw;
        }
    }
}