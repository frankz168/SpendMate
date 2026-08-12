using Microsoft.Extensions.Logging;
using System.Diagnostics;

public class ReportService
{
    private readonly IReportRepository _repo;
    private readonly ITransactionRepository _transactionRepo;
    private readonly IConfigRepository _config;
    private readonly EmailService _email;
    private readonly ILogger<ReportService> _logger;

    public ReportService(
        IReportRepository repo,
        ITransactionRepository transactionRepo,
        IConfigRepository config,
        EmailService email,
        ILogger<ReportService> logger)
    {
        _repo = repo;
        _transactionRepo = transactionRepo;
        _config = config;
        _email = email;
        _logger = logger;
    }

    public void SendReport(string type, int userId)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation("📊 Start Report: {Type}", type);

            var now = DateTime.Now;

            // ================= RANGE
            DateTime from;
            DateTime to = now;

            switch (type.ToLower())
            {
                case "daily":
                    from = now.Date;
                    break;

                case "weekly":
                    int diff = (7 + (now.DayOfWeek - DayOfWeek.Monday)) % 7;
                    from = now.AddDays(-diff).Date;
                    break;

                case "monthly":
                default:
                    from = new DateTime(now.Year, now.Month, 1);
                    break;
            }

            // ================= TOTAL (Expenses Only for Budget)
            decimal total = _transactionRepo.GetTotalByType(userId, from, to, "Expense");

            // ================= DETAIL
            var data = _repo.GetReportData(type, userId);

            // ================= BUDGET
            decimal budget = _config.GetDecimal("MonthlyBudget");

            decimal remaining = budget - total;
            decimal percent = budget == 0 ? 0 : (total / budget) * 100;

            string topCategory = data
                .OrderByDescending(x => x.Total)
                .FirstOrDefault()?.Category ?? "-";

            bool isOverBudget = total > budget;

            // ================= BUILD EMAIL
            string html = BuildTemplate(
                type,
                total,
                budget,
                remaining,
                percent,
                data,
                topCategory,
                isOverBudget,
                now
            );

            // ================= SEND EMAIL
            var emails = _config.GetStringList("Report_EmailTo");
            foreach (var email in emails)
            {
                _email.Send(
                    email,
                    $"💼 SpendMate {type.ToUpper()} Report",
                    html
                );
            }

            sw.Stop();

            _logger.LogInformation(
                "✅ Report {Type} SUCCESS | Total={Total} | {Ms}ms",
                type,
                total,
                sw.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            sw.Stop();

            _logger.LogError(
                ex,
                "❌ Report FAILED: {Type} ({Ms}ms)",
                type,
                sw.ElapsedMilliseconds
            );
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
        bool isOverBudget,
        DateTime now)
    {
        int dayNow = now.Day;
        int daysInMonth = DateTime.DaysInMonth(now.Year, now.Month);

        string statusSection = isOverBudget
            ? $@"
                <p style='color:red'><b>❌ Over budget: Rp{Math.Abs(remaining):N0}</b></p>
                <p><b>Used:</b> {percent:0}%</p>
                <p>💡 You are over budget, try reducing the highest expense</p>
              "
            : $@"
                <p style='color:green'><b>✅ Remaining budget: Rp{remaining:N0}</b></p>
                <p><b>Used:</b> {percent:0}%</p>
                <p>💡 Your spending is still under control 👍</p>
              ";

        var detail = string.Join("", data.Select(x =>
            $"<li>{Icon(x.Category)} {x.Category}: Rp{x.Total:N0}</li>"
        ));

        return $@"
        <div style='font-family:Arial'>
            <h2>💼 SpendMate Report</h2>
            <h3>📊 {type.ToUpper()} Summary</h3>

            <p><b>Total Expenses:</b> Rp{total:N0}</p>
            <p><b>Budget (Monthly):</b> Rp{budget:N0}</p>

            <p>📆 Day: {dayNow} / {daysInMonth}</p>

            {statusSection}

            <h4>📌 Expense Breakdown:</h4>
            <ul>{detail}</ul>

            <p>🔥 Top spending category: <b>{topCategory}</b></p>
        </div>";
    }

    private string Icon(string cat)
    {
        return cat switch
        {
            "Food" => "🍽️",
            "Transport" => "🚗",
            "Shopping" => "🛍️",
            _ => "📦"
        };
    }
}