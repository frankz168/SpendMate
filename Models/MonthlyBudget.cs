namespace SpendMate.Models;

public class MonthlyBudget
{
    public int Id { get; set; }
    public string GroupType { get; set; } = "";
    public string Category { get; set; } = "";
    public decimal TargetAmount { get; set; }
    public decimal ActualAmount { get; set; }
    public bool IsPaid { get; set; }
}
