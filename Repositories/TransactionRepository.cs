using Dapper;
using Microsoft.Extensions.Logging;
using System.Data;
using System.Diagnostics;

public class TransactionRepository : ITransactionRepository
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
                "SELECT spendmate_dashboard_getdailytotal(@UserId);",
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
                "SELECT * FROM spendmate_dashboard_getdailysummary(@UserId);",
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
        var toInclusive = to.Date.AddDays(1);

        try
        {
            using var conn = _db.CreateConnection();

            var data = conn.Query<Transaction>(
                "SELECT * FROM spendmate_transaction_getlist(@UserId, @FromDate::timestamp, @ToDate::timestamp);",
                new
                {
                    UserId = userId,
                    FromDate = from,
                    ToDate = toInclusive
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
                "SELECT * FROM spendmate_transaction_getbyid(@id, @UserId);",
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

            var id = conn.ExecuteScalar<int>(
                "SELECT spendmate_transaction_insert(@UserId, @Type, @Amount, @Category, @Destination, @Note, @IsRecurring, @Createdate);",
                new
                {
                    UserId = model.UserId,
                    Type = model.Type,
                    Amount = model.Amount,
                    Category = model.Category,
                    Destination = model.Destination,
                    Note = model.Note,
                    IsRecurring = model.IsRecurring,
                    Createdate = model.Createdate
                }
            );

            _logger.LogInformation(
                "Insert Transaction | UserId={UserId}, Type={Type}, Amount={Amount}, Category={Category}, Date={Date}",
                model.UserId, model.Type, model.Amount, model.Category, model.Createdate);
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
                "SELECT spendmate_transaction_update(@Id, @UserId, @Type, @Amount, @Category, @Destination, @Note, @IsRecurring);",
                new
                {
                    Id = model.Id,
                    UserId = model.UserId,
                    Type = model.Type,
                    Amount = model.Amount,
                    Category = model.Category,
                    Destination = model.Destination,
                    Note = model.Note,
                    IsRecurring = model.IsRecurring
                }
            );

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
                "SELECT spendmate_transaction_delete(@id, @UserId);",
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
        DateTime? toInclusive = to.HasValue ? to.Value.Date.AddDays(1) : null;

        try
        {
            using var conn = _db.CreateConnection();

            var data = conn.Query(
                "SELECT * FROM spendmate_transaction_exportall(@UserId, @FromDate::timestamp, @ToDate::timestamp);",
                new
                {
                    UserId = userId,
                    FromDate = from,
                    ToDate = toInclusive
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
            "SELECT spendmate_transaction_gettotalbytype(@UserId, @From::timestamp, @To::timestamp, @Type::VARCHAR);",
            new
            {
                UserId = userId,
                Type = type,
                From = from,
                To = toInclusive
            });
    }
}