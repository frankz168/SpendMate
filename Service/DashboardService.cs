public class DashboardService
{
    private readonly ExpenseRepository _expenseRepo;
    private readonly ReportRepository _reportRepo;

    public DashboardService(
        ExpenseRepository expenseRepo,
        ReportRepository reportRepo)
    {
        _expenseRepo = expenseRepo;
        _reportRepo = reportRepo;
    }


    public DailySummaryVM GetDailySummary(int userId)
    {
        var now = DateTime.Now;

        var todayFrom = now.Date;
        var monthFrom = new DateTime(now.Year, now.Month, 1);
        var to = now;

        var vm = new DailySummaryVM();

        // ================= TODAY
        vm.Total = _expenseRepo.GetTotalExpense(userId, todayFrom, to);

        // ================= MONTHLY
        vm.MonthlyTotal = _expenseRepo.GetTotalExpense(userId, monthFrom, to);

        // ================= BUDGET
        vm.Budget = ApplicationConfig.MonthlyBudget;

        vm.Remaining = vm.Budget - vm.MonthlyTotal;

        // ================= BREAKDOWN (HARI INI)
        vm.Items = _reportRepo.GetReportData("daily");

        return vm;
    }
}