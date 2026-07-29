using Microsoft.Extensions.Logging;
using System.Diagnostics;

public class TransactionService
{
    private readonly TransactionRepository _repo;
    private readonly ILogger<TransactionService> _logger;

    public TransactionService(
        TransactionRepository repo,
        ILogger<TransactionService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public IEnumerable<Transaction> GetTransactions(int userId, DateTime from, DateTime to)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation(
                "📥 GetTransactions START | UserId={UserId}, From={From}, To={To}",
                userId, from, to);

            var data = _repo.GetTransactions(userId, from, to);

            sw.Stop();

            _logger.LogInformation(
                "✅ GetTransactions SUCCESS | Count={Count}, Duration={Ms}ms",
                data.Count(), sw.ElapsedMilliseconds);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "❌ GetTransactions FAILED | UserId={UserId}",
                userId);

            throw;
        }
    }

    public Transaction GetById(int id, int userId)
    {
        try
        {
            _logger.LogInformation(
                "🔍 GetById START | Id={Id}, UserId={UserId}",
                id, userId);

            var data = _repo.GetById(id, userId);

            _logger.LogInformation(
                "✅ GetById SUCCESS | Found={Found}",
                data != null);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "❌ GetById FAILED | Id={Id}, UserId={UserId}",
                id, userId);

            throw;
        }
    }

    public void Save(Transaction model)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation(
                "💾 Save START | Id={Id}, Category={Category}, Amount={Amount}",
                model.Id, model.Category, model.Amount);

            if (model.Id == 0)
            {
                _repo.Insert(model);
                _logger.LogInformation("➕ Insert executed");
            }
            else
            {
                _repo.Update(model);
                _logger.LogInformation("✏️ Update executed");
            }

            sw.Stop();

            _logger.LogInformation(
                "✅ Save SUCCESS | Duration={Ms}ms",
                sw.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "❌ Save FAILED | Id={Id}",
                model.Id);

            throw;
        }
    }

    public void Delete(int id, int userId)
    {
        try
        {
            _logger.LogInformation(
                "🗑 Delete START | Id={Id}, UserId={UserId}",
                id, userId);

            _repo.Delete(id, userId);

            _logger.LogInformation(
                "✅ Delete SUCCESS | Id={Id}",
                id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "❌ Delete FAILED | Id={Id}",
                id);

            throw;
        }
    }

    public IEnumerable<dynamic> Export(int userId, DateTime? from, DateTime? to)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation(
                "📤 Export START | UserId={UserId}, From={From}, To={To}",
                userId, from, to);

            var data = _repo.GetAllForExport(userId, from, to);

            sw.Stop();

            _logger.LogInformation(
                "✅ Export SUCCESS | Count={Count}, Duration={Ms}ms",
                data.Count(), sw.ElapsedMilliseconds);

            return data;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "❌ Export FAILED | UserId={UserId}",
                userId);

            throw;
        }
    }
}