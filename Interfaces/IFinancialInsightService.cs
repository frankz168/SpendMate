using System.Threading.Tasks;

public interface IFinancialInsightService
{
    Task<FinancialInsightDto> GetMonthlyInsightsAsync(int userId);
}
