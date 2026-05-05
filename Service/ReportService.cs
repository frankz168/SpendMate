using Microsoft.Extensions.Logging;
using System.Diagnostics;

public class ReportService
{
    private readonly ReportRepository _repo;
    private readonly EmailService _email;
    private readonly ILogger<ReportService> _logger;

    public ReportService(
        ReportRepository repo,
        EmailService email,
        ILogger<ReportService> logger)
    {
        _repo = repo;
        _email = email;
        _logger = logger;
    }

    public void SendReport(string type, string emailTo)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation("📊 Start Report: {Type}", type);

            // ================= DB
            var data = _repo.GetReportData(type);

            // ================= CALCULATION
            decimal total = data.Sum(x => x.Total);
            decimal budget = ApplicationConfig.Budget;
            decimal remaining = budget - total;
            decimal percent = budget == 0 ? 0 : (total / budget) * 100;

            string topCategory = data
                .OrderByDescending(x => x.Total)
                .FirstOrDefault()?.Category ?? "-";

            bool isOverBudget = total > budget;

            // ================= TEMPLATE
            string html = BuildTemplate(
                type,
                total,
                budget,
                remaining,
                percent,
                data,
                topCategory,
                isOverBudget
            );

            // ================= EMAIL
            _email.Send(emailTo, $"💼 SpendMate {type.ToUpper()} Report", html);

            sw.Stop();

            _logger.LogInformation(
                "✅ Report {Type} sent ({Ms} ms)",
                type,
                sw.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            sw.Stop();

            _logger.LogError(
                ex,
                "❌ Report failed: {Type} ({Ms} ms)",
                type,
                sw.ElapsedMilliseconds
            );

            // ❌ DO NOT THROW (scheduler safe)
        }
    }

    // ================= TEMPLATE =================
    private string BuildTemplate(
        string type,
        decimal total,
        decimal budget,
        decimal remaining,
        decimal percent,
        List<ReportItem> data,
        string topCategory,
        bool isOverBudget)
    {
        string statusSection = isOverBudget
            ? $@"
                <p style='color:red'><b>❌ Melebihi budget: Rp{Math.Abs(remaining):N0}</b></p>
                <p><b>Terpakai:</b> {percent:0}%</p>
                <p>💡 Kamu over budget, coba tekan pengeluaran terbesar</p>
              "
            : $@"
                <p style='color:green'><b>✅ Sisa budget: Rp{remaining:N0}</b></p>
                <p><b>Terpakai:</b> {percent:0}%</p>
                <p>💡 Pengeluaran masih aman 👍</p>
              ";

        var detail = string.Join("", data.Select(x =>
            $"<li>{Icon(x.Category)} {x.Category}: Rp{x.Total:N0}</li>"
        ));

        return $@"
        <div style='font-family:Arial'>
            <h2>💼 SpendMate Report</h2>
            <h3>📊 {type.ToUpper()} Summary</h3>

            <p><b>Total:</b> Rp{total:N0}</p>
            <p><b>Budget:</b> Rp{budget:N0}</p>

            {statusSection}

            <h4>📌 Detail Pengeluaran:</h4>
            <ul>{detail}</ul>

            <p>🔥 Pengeluaran terbesar: <b>{topCategory}</b></p>
        </div>";
    }

    private string Icon(string cat)
    {
        return cat switch
        {
            "Makan" => "🍽️",
            "Transport" => "🚗",
            "Belanja" => "🛍️",
            _ => "📦"
        };
    }
}