using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using SpendMate.Models;

public class SettingsViewModel
{
    public decimal MonthlyIncomeTarget { get; set; }
    public List<Category> Categories { get; set; } = new List<Category>();
}

[Authorize]
public class SettingsController : BaseController
{
    private readonly ICategoryRepository _categoryRepo;
    private readonly IConfigRepository _configRepo;

    public SettingsController(ICategoryRepository categoryRepo, IConfigRepository configRepo)
    {
        _categoryRepo = categoryRepo;
        _configRepo = configRepo;
    }

    public IActionResult Index()
    {
        var vm = new SettingsViewModel
        {
            MonthlyIncomeTarget = _configRepo.GetDecimal("MonthlyBudget", 0),
            Categories = _categoryRepo.GetAll()
        };
        return View(vm);
    }

    [HttpPost]
    public IActionResult SaveIncome([FromForm] decimal targetAmount)
    {
        _configRepo.SetString("MonthlyBudget", targetAmount.ToString(System.Globalization.CultureInfo.InvariantCulture));
        return RedirectToAction("Index");
    }

    [HttpPost]
    public IActionResult SaveCategory([FromForm] Category category)
    {
        category.IsActive = true; // Always true on save/add
        _categoryRepo.Save(category);
        return RedirectToAction("Index");
    }

    [HttpPost]
    public IActionResult DeleteCategory(int id)
    {
        _categoryRepo.Delete(id);
        return RedirectToAction("Index");
    }
}
