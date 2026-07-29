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
        // string emailTo = "franky.sutanto93@gmail.com";
        _service.SendReport(type);
        return Ok();
    }
}