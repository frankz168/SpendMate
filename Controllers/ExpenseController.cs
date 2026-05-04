using Microsoft.AspNetCore.Mvc;
using OfficeOpenXml;

public class ExpenseController : Controller
{
    private readonly ExpenseService _service;

    public ExpenseController(ExpenseService service)
    {
        _service = service;
    }

    public IActionResult Index()
    {
        return View();
    }

    [HttpGet]
    public IActionResult GetData()
    {
        var result = _service.GetDashboard(1);
        return Json(result);
    }

    [HttpGet]
    public IActionResult GetById(int id)
    {
        var data = _service.GetById(id, 1);
        return Json(data);
    }

    [HttpPost]
    public IActionResult Save([FromBody] Expense model)
    {
        model.UserId = 1;
        _service.Save(model);
        return Ok();
    }

    [HttpPost]
    public IActionResult Delete(int id)
    {
        _service.Delete(id, 1);
        return Ok();
    }

    public IActionResult ExportExcel()
    {
        ExcelPackage.License.SetNonCommercialOrganization("SpendMate");

        var data = _service.Export(1);

        using var package = new ExcelPackage();
        var ws = package.Workbook.Worksheets.Add("Expenses");

        ws.Cells[1, 1].Value = "Date";
        ws.Cells[1, 2].Value = "Category";
        ws.Cells[1, 3].Value = "Amount";
        ws.Cells[1, 4].Value = "Note";

        ws.Row(1).Style.Font.Bold = true;

        int row = 2;

        foreach (var x in data)
        {
            ws.Cells[row, 1].Value = Convert.ToDateTime(x.createdate);
            ws.Cells[row, 1].Style.Numberformat.Format = "yyyy-MM-dd HH:mm";

            ws.Cells[row, 2].Value = x.category;
            ws.Cells[row, 3].Value = x.amount;
            ws.Cells[row, 4].Value = x.note;

            row++;
        }

        ws.Cells[ws.Dimension.Address].AutoFitColumns();

        var stream = new MemoryStream();
        package.SaveAs(stream);
        stream.Position = 0;

        return File(stream,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            $"SpendMate_{DateTime.Now:yyyyMMdd}.xlsx");
    }
}