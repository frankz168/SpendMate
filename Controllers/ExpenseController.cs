using OfficeOpenXml;
using System.IO;
using System.Data;
using Dapper;
using Microsoft.AspNetCore.Mvc;

public class ExpenseController : Controller
{
    private readonly DbConnectionFactory _db;

    public ExpenseController(DbConnectionFactory db)
    {
        _db = db;
    }

    public IActionResult Index()
    {
        return View();
    }

    // =========================
    // DASHBOARD DATA
    // =========================
    [HttpGet]
    public IActionResult GetData()
    {
        using var conn = _db.CreateConnection();

        var userId = 1;

        var total = conn.ExecuteScalar<decimal>(
            "SELECT get_daily_total(@UserId);",
            new { UserId = userId }
        );

        var summary = conn.Query(
            "SELECT * FROM get_daily_summary(@UserId);",
            new { UserId = userId }
        );

        var expenses = conn.Query(@"
            SELECT id, amount, category, note, createdate
            FROM expenses
            WHERE userid = @UserId
              AND createdate >= CURRENT_DATE
              AND createdate < CURRENT_DATE + INTERVAL '1 day'
            ORDER BY createdate DESC",
            new { UserId = userId }
        );

        return Json(new { total, summary, expenses });
    }

    // =========================
    // ADD
    // =========================
    [HttpPost]
    public IActionResult Add([FromBody] Expense model)
    {
        using var conn = _db.CreateConnection();

        model.UserId = 1;

        conn.ExecuteScalar<int>(
            "SELECT insert_expense(@UserId, @Amount, @Category, @Note);",
            model
        );

        return Ok();
    }

    // =========================
    // DATATABLE SOURCE
    // =========================
    [HttpGet]
    public IActionResult GetDataTable()
    {
        using var conn = _db.CreateConnection();

        var userId = 1;

        var expenses = conn.Query(@"
            SELECT id, amount, category, note, createdate
            FROM expenses
            WHERE userid = @UserId
            ORDER BY createdate DESC",
            new { UserId = userId });

        return Json(new { data = expenses });
    }

    // =========================
    // GET BY ID (EDIT)
    // =========================
    [HttpGet]
    public IActionResult GetById(int id)
    {
        using var conn = _db.CreateConnection();

        var userId = 1;

        var data = conn.QueryFirstOrDefault(@"
            SELECT id, amount, category, note
            FROM expenses
            WHERE id = @id AND userid = @UserId",
            new { id, UserId = userId });

        return Json(data);
    }

    // =========================
    // SAVE (INSERT + UPDATE)
    // =========================
    [HttpPost]
    public IActionResult Save([FromBody] Expense model)
    {
        using var conn = _db.CreateConnection();

        model.UserId = 1;

        if (model.Id == 0)
        {
            conn.Execute(@"
                INSERT INTO expenses(userid, amount, category, note, createdate)
                VALUES (@UserId, @Amount, @Category, @Note, NOW())",
                model);
        }
        else
        {
            conn.Execute(@"
                UPDATE expenses
                SET amount = @Amount,
                    category = @Category,
                    note = @Note
                WHERE id = @Id AND userid = @UserId",
                model);
        }

        return Ok();
    }

    // =========================
    // DELETE
    // =========================
    [HttpPost]
    public IActionResult Delete(int id)
    {
        using var conn = _db.CreateConnection();

        conn.Execute(@"
            DELETE FROM expenses 
            WHERE id = @id AND userid = 1",
            new { id });

        return Ok();
    }

    public IActionResult ExportExcel()
    {
        using var conn = _db.CreateConnection();

        // 🔥 IMPORTANT: EPPlus 8 license
        ExcelPackage.License.SetNonCommercialOrganization("SpendMate");

        // =========================
        // GET DATA
        // =========================
        var data = conn.Query(@"
            SELECT createdate, category, amount, note
            FROM expenses
            WHERE userid = 1
            ORDER BY createdate DESC
        ").ToList();

        using var package = new ExcelPackage();
        var ws = package.Workbook.Worksheets.Add("Expenses");

        // =========================
        // HEADER
        // =========================
        ws.Cells[1, 1].Value = "Date";
        ws.Cells[1, 2].Value = "Category";
        ws.Cells[1, 3].Value = "Amount";
        ws.Cells[1, 4].Value = "Note";

        ws.Row(1).Style.Font.Bold = true;

        // =========================
        // DATA
        // =========================
        int row = 2;

        foreach (var x in data)
        {
            ws.Cells[row, 1].Value = x.createdate;
            ws.Cells[row, 1].Style.Numberformat.Format = "yyyy-MM-dd HH:mm";

            ws.Cells[row, 2].Value = x.category;
            ws.Cells[row, 3].Value = x.amount;
            ws.Cells[row, 4].Value = x.note;

            row++;
        }

        // =========================
        // FORMAT TABLE
        // =========================
        ws.Cells[ws.Dimension.Address].AutoFitColumns();

        // =========================
        // OUTPUT FILE
        // =========================
        var stream = new MemoryStream();
        package.SaveAs(stream);
        stream.Position = 0;

        string fileName = $"SpendMate_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";

        return File(
            stream,
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            fileName
        );
    }
}