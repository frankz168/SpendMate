public class DashboardService
{
    private readonly DashboardRepository _repo;

    public DashboardService(DashboardRepository repo)
    {
        _repo = repo;
    }

    public DailySummaryVM GetDailySummary(int userId)
    {
        return new DailySummaryVM
        {
            Total = _repo.GetTotal(userId),
            Items = _repo.GetSummary(userId)
        };
    }
}