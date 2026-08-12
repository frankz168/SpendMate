public class DashboardService
{
    private readonly ITransactionRepository _repo;
    private readonly IReportRepository _reportRepo;
    private readonly IConfigRepository _config;
    private readonly IDashboardRepository _dashRepo;

    public DashboardService(
        ITransactionRepository repo,
        IReportRepository reportRepo,
        IConfigRepository config,
        IDashboardRepository dashRepo)
    {
        _repo = repo;
        _reportRepo = reportRepo;
        _config = config;
        _dashRepo = dashRepo;
    }

    public DailySummaryVM GetDailySummary(int userId)
    {
        var now = DateTime.Now;

        var todayFrom = now.Date;
        var monthFrom = new DateTime(now.Year, now.Month, 1);
        var to = now;

        var vm = new DailySummaryVM();

        // ================= TODAY
        vm.TodayIncome = _repo.GetTotalByType(userId, todayFrom, to, "Income");
        vm.TodayExpense = _repo.GetTotalByType(userId, todayFrom, to, "Expense");
        vm.TodayTransfer = _repo.GetTotalByType(userId, todayFrom, to, "Transfer");

        // ================= MONTHLY
        vm.MonthlyIncome = _repo.GetTotalByType(userId, monthFrom, to, "Income");
        vm.MonthlyExpense = _repo.GetTotalByType(userId, monthFrom, to, "Expense");
        vm.MonthlyTransfer = _repo.GetTotalByType(userId, monthFrom, to, "Transfer");

        vm.NetBalance = vm.MonthlyIncome - vm.MonthlyExpense;

        // ================= BUDGET
        vm.Budget = _config.GetDecimal("MonthlyBudget", 0);
        vm.RemainingBudget = vm.Budget - vm.MonthlyExpense;

        // ================= BREAKDOWN (THIS MONTH EXPENSES)
        vm.Items = _reportRepo.GetReportData("monthly", userId); 

        // ================= TREND (LAST 6 MONTHS)
        vm.TrendItems = _dashRepo.Get6MonthTrend(userId);

        return vm;
    }
}