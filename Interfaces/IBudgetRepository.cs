using System.Collections.Generic;
using SpendMate.Models;

public interface IBudgetRepository
{
    List<MonthlyBudget> GetMonthlyRecap(int userId, int year, int month);
    void SaveBudget(int userId, int year, int month, string groupType, string category, decimal targetAmount, bool isPaid);
}
