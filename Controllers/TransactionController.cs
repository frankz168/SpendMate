using Microsoft.AspNetCore.Mvc;
using OfficeOpenXml;

public class TransactionController : Controller
{
    private readonly TransactionService _service;

    public TransactionController(TransactionService service)
    {
        _service = service;
    }

    public IActionResult Index()
    {
        return View();
    }

   [HttpGet]
    public IActionResult GetData(DateTime from, DateTime to)
    {
        var result = _service.GetTransactions(1, from, to);
        return Json(result);
    }

    [HttpGet]
    public IActionResult GetById(int id)
    {
        var data = _service.GetById(id, 1);
        return Json(data);
    }

    [HttpPost]
    public IActionResult Save([FromBody] Transaction model)
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

   [HttpGet]
    public IActionResult ExportExcel(DateTime? from, DateTime? to)
    {
        ExcelPackage.License.SetNonCommercialOrganization("SpendMate");

        var data = _service.Export(1, from, to);

        using var package = new ExcelPackage();
        var ws = package.Workbook.Worksheets.Add("Transactions");

        // ================= HEADER
        ws.Cells[1, 1].Value = "Date";
        ws.Cells[1, 2].Value = "Type";
        ws.Cells[1, 3].Value = "Category";
        ws.Cells[1, 4].Value = "Destination";
        ws.Cells[1, 5].Value = "Amount";
        ws.Cells[1, 6].Value = "Note";

        ws.Row(1).Style.Font.Bold = true;

        int row = 2;

        // ================= DATA
        foreach (var x in data)
        {
            ws.Cells[row, 1].Value = Convert.ToDateTime(x.createdate);
            ws.Cells[row, 1].Style.Numberformat.Format = "yyyy-MM-dd HH:mm";

            ws.Cells[row, 2].Value = x.type;
            ws.Cells[row, 3].Value = x.category;
            ws.Cells[row, 4].Value = x.destination;
            ws.Cells[row, 5].Value = x.amount;
            ws.Cells[row, 6].Value = x.note;

            row++;
        }

        // ================= AUTO FIT
        ws.Cells[ws.Dimension.Address].AutoFitColumns();

        // ================= STREAM
        var stream = new MemoryStream();
        package.SaveAs(stream);
        stream.Position = 0;

        string fileName = from.HasValue && to.HasValue
            ? $"SpendMate_{from:yyyyMMdd}_{to:yyyyMMdd}.xlsx"
            : $"SpendMate_{DateTime.Now:yyyyMMdd}.xlsx";

        return File(stream,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            fileName);
    }

    [HttpGet]
    public IActionResult List(DateTime from, DateTime to, string category)
    {
        var data = _service.GetTransactions(1, from, to);

        if (!string.IsNullOrEmpty(category))
            data = data.Where(x => x.Category == category);

        ViewBag.Category = category;

        return View(data);
    }
}