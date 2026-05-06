using System.Collections.Generic;

public class DailySummaryVM
{
    public decimal Total { get; set; } // today
    public decimal MonthlyTotal { get; set; }
    public decimal Budget { get; set; }
    public decimal Remaining { get; set; }
    public List<ReportItem> Items { get; set; } = new List<ReportItem>();
}