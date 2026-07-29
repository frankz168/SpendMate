using Dapper;
using Microsoft.Extensions.Logging;
using System.Data;
using System.Diagnostics;

public class TransactionRepository
{
    private readonly DbConnectionFactory _db;
    private readonly ILogger<TransactionRepository> _logger;

    public TransactionRepository(
        DbConnectionFactory db,
        ILogger<TransactionRepository> logger)
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

    public IEnumerable<Transaction> GetTransactions(int userId, DateTime from, DateTime to)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            using var conn = _db.CreateConnection();

            var data = conn.Query<Transaction>(
                "SELECT * FROM get_transactions(@UserId, @FromDate, @ToDate);",
                new
                {
                    UserId = userId,
                    FromDate = from,
                    ToDate = to
                }).ToList();

            sw.Stop();

            _logger.LogInformation(
                "GetTransactions | UserId={UserId}, Count={Count}, {Ms}ms",
                userId, data.Count, sw.ElapsedMilliseconds);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "GetTransactions FAILED | UserId={UserId}",
                userId);
            throw;
        }
    }

    public Transaction GetById(int id, int userId)
    {
        try
        {
            using var conn = _db.CreateConnection();

            var data = conn.QueryFirstOrDefault<Transaction>(
                "SELECT * FROM get_transaction_by_id(@id, @UserId);",
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

    public void Insert(Transaction model)
    {
        try
        {
            using var conn = _db.CreateConnection();

            conn.Execute(
                "SELECT insert_transaction(@UserId, @Type::VARCHAR, @Amount, @Category::VARCHAR, @Destination::VARCHAR, @Note::TEXT);",
                model);

            _logger.LogInformation(
                "Insert Transaction | UserId={UserId}, Type={Type}, Amount={Amount}, Category={Category}",
                model.UserId, model.Type, model.Amount, model.Category);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Insert FAILED | UserId={UserId}",
                model.UserId);
            throw;
        }
    }

    public void Update(Transaction model)
    {
        try
        {
            using var conn = _db.CreateConnection();

            conn.Execute(
                "SELECT update_transaction(@Id, @UserId, @Type::VARCHAR, @Amount, @Category::VARCHAR, @Destination::VARCHAR, @Note::TEXT);",
                model);

            _logger.LogInformation(
                "Update Transaction | Id={Id}, UserId={UserId}",
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

            conn.Execute(
                "SELECT delete_transaction(@id, @UserId);",
                new { id, UserId = userId });

            _logger.LogInformation(
                "Delete Transaction | Id={Id}, UserId={UserId}",
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

            var data = conn.Query(
                "SELECT * FROM get_all_for_export(@UserId, @FromDate, @ToDate);",
                new
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

    public decimal GetTotalByType(int userId, DateTime from, DateTime to, string type)
    {
        using var conn = _db.CreateConnection();

        var toInclusive = to.Date.AddDays(1);

        return conn.ExecuteScalar<decimal>(
            "SELECT get_total_by_type(@UserId, @From, @To, @Type::VARCHAR);",
            new
            {
                UserId = userId,
                Type = type,
                From = from,
                To = toInclusive
            });
    }
}