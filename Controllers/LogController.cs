using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

[Authorize]
public class LogController : BaseController
{
    private readonly string _logDir;

    public LogController()
    {
        _logDir = Path.Combine(Directory.GetCurrentDirectory(), "logs");
    }

    // Page UI
    public IActionResult Index()
    {
        return View();
    }

    // API: ambil isi log
    [HttpGet]
    public IActionResult Get(string? file = null, int take = 200)
    {
        try
        {
            if (!Directory.Exists(_logDir))
                return Json(new { files = new string[0], content = "" });

            var files = Directory.GetFiles(_logDir, "spendmate*.log")
                                 .OrderByDescending(f => f)
                                 .ToList();

            if (files.Count == 0)
                return Json(new { files, content = "" });

            var selected = file ?? Path.GetFileName(files.First());
            var fullPath = Path.Combine(_logDir, selected);

            if (!System.IO.File.Exists(fullPath))
                return Json(new { files, content = "" });

            // ambil last N lines (simple)
            var lines = System.IO.File.ReadAllLines(fullPath);
            var content = string.Join("\n", lines.TakeLast(take));

            return Json(new
            {
                files = files.Select(Path.GetFileName),
                content,
                selected
            });
        }
        catch (Exception ex)
        {
            return Json(new { error = ex.Message });
        }
    }
}