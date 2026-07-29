using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

[Authorize]
public class ReportController : BaseController
{
    private readonly ReportService _service;

    public ReportController(ReportService service)
    {
        _service = service;
    }

    public IActionResult Index()
    {
        return View();
    }

    [HttpPost]
    public IActionResult Send(string type)
    {
        _service.SendReport(type, GetUserId());
        return Ok();
    }
}