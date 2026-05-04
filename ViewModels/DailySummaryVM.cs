using System.Collections.Generic;

public class DailySummaryVM
{
    public decimal Total { get; set; }
    public List<DailyItemVM> Items { get; set; } = new List<DailyItemVM>();
}