namespace SpendMate.Models;

public class Category
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public string GroupType { get; set; } = "";
    public decimal DefaultTarget { get; set; }
    public bool IsActive { get; set; }
}
