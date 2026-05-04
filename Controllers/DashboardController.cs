using Microsoft.AspNetCore.Mvc;
using OfficeOpenXml;

public class DashboardController : Controller
{
    private readonly DashboardService _service;

    public DashboardController(DashboardService service)
    {
        _service = service;
    }

    public IActionResult Index()
    {
        var vm = _service.GetDailySummary(1);
        return View(vm);
    }
}