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

    public async Task<IActionResult> Index()
    {
        var vm = await _service.GetDailySummaryAsync(GetUserId());
        return View(vm);
    }
}