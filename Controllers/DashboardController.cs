using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using OfficeOpenXml;

[Authorize]
public class DashboardController : BaseController
{
    private readonly DashboardService _service;

    public DashboardController(DashboardService service)
    {
        _service = service;
    }

    public IActionResult Index()
    {
        var vm = _service.GetDailySummary(GetUserId());
        return View(vm);
    }
}