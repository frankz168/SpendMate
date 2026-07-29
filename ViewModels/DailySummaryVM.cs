using System.Collections.Generic;

public class DailySummaryVM
{
    public decimal TodayIncome { get; set; }
    public decimal TodayExpense { get; set; }
    public decimal TodayTransfer { get; set; }
    
    public decimal MonthlyIncome { get; set; }
    public decimal MonthlyExpense { get; set; }
    public decimal MonthlyTransfer { get; set; }
    
    public decimal NetBalance { get; set; } // MonthlyIncome - MonthlyExpense
    public decimal Budget { get; set; }
    public decimal RemainingBudget { get; set; } // Budget - MonthlyExpense

    public List<ReportItem> Items { get; set; } = new List<ReportItem>();
}