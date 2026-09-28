using System;
using System.Threading.Tasks;

public class DashboardService
{
    private readonly ITransactionRepository _repo;
    private readonly IReportRepository _reportRepo;
    private readonly IConfigRepository _config;
    private readonly IDashboardRepository _dashRepo;
    private readonly ICacheService _cache;

    public DashboardService(
        ITransactionRepository repo,
        IReportRepository reportRepo,
        IConfigRepository config,
        IDashboardRepository dashRepo,
        ICacheService cache)
    {
        _repo = repo;
        _reportRepo = reportRepo;
        _config = config;
        _dashRepo = dashRepo;
        _cache = cache;
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

    public async Task<DailySummaryVM> GetDailySummaryAsync(int userId)
    {
        string cacheKey = $"Dashboard_Summary_{userId}_{DateTime.Now:yyyyMMdd_HH}";
        
        var cached = await _cache.GetAsync<DailySummaryVM>(cacheKey);
        if (cached != null)
        {
            return cached;
        }

        var vm = GetDailySummary(userId);
        
        // Cache for 10 minutes
        await _cache.SetAsync(cacheKey, vm, TimeSpan.FromMinutes(10));
        
        return vm;
    }
}