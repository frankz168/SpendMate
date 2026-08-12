using Microsoft.Extensions.Logging;
using System.Diagnostics;
using System.IO;
using OfficeOpenXml;

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

    public void UploadBcaStatement(Stream fileStream, int userId)
    {
        ExcelPackage.LicenseContext = LicenseContext.NonCommercial;
        using var package = new ExcelPackage(fileStream);
        var ws = package.Workbook.Worksheets.FirstOrDefault();
        if (ws == null) throw new Exception("No worksheet found.");

        int rowCount = ws.Dimension?.Rows ?? 0;

        for (int row = 1; row <= rowCount; row++)
        {
            var dateStr = ws.Cells[row, 1].Text?.Trim();
            if (string.IsNullOrWhiteSpace(dateStr)) continue;

            if (dateStr.StartsWith("'")) dateStr = dateStr.Substring(1);

            if (DateTime.TryParseExact(dateStr, "dd/MM/yyyy", null, System.Globalization.DateTimeStyles.None, out DateTime txDate) ||
                DateTime.TryParse(dateStr, new System.Globalization.CultureInfo("id-ID"), System.Globalization.DateTimeStyles.None, out txDate))
            {
                var note = ws.Cells[row, 2].Text?.Trim() ?? "";
                var amountStr = ws.Cells[row, 4].Text?.Trim() ?? "0";
                
                if (!decimal.TryParse(amountStr.Replace(",", "").Replace(".", ""), out decimal amount)) 
                    continue;

                var typeStr = ws.Cells[row, 5].Text?.Trim() ?? "DB";

                string category = "OTHERS";
                string noteUpper = note.ToUpper();
                
                if (noteUpper.Contains("KARTU KREDIT")) category = "Credit Card Statement";
                else if (noteUpper.Contains("TOKOPEDIA")) category = "SHOPPING";
                else if (noteUpper.Contains("HARTADINATA")) category = "GOLD 5GR";
                else if (noteUpper.Contains("DIGITRAVEL")) category = "RECREATION";
                else if (noteUpper.Contains("FRANKY") || noteUpper.Contains("FAM") || noteUpper.Contains("FEITY") || noteUpper.Contains("FETTY")) category = "FRANKY PARENTS";
                else if (noteUpper.Contains("EVE") || noteUpper.Contains("JOVITA")) category = "EVE PARENTS";

                string txType = typeStr.Equals("CR", StringComparison.OrdinalIgnoreCase) ? "Income" : "Expense";
                
                var model = new Transaction
                {
                    UserId = userId,
                    Createdate = txDate,
                    Note = note,
                    Amount = amount,
                    Category = category,
                    Type = txType,
                    Destination = ""
                };

                _repo.Insert(model);
            }
        }
    }
}