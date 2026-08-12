using System.Collections.Generic;

public interface IDashboardRepository
{
    decimal GetTotal(int userId);
    List<DailyItemVM> GetSummary(int userId);
    List<SpendMate.Models.TrendItem> Get6MonthTrend(int userId);
}
