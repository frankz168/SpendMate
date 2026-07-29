using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using SpendMate.Models;
using OfficeOpenXml;
using OfficeOpenXml.Style;
using System.Drawing;

public class SaveBudgetDto
{
    public int Year { get; set; }
    public int Month { get; set; }
    public string GroupType { get; set; } = "";
    public string Category { get; set; } = "";
    public decimal TargetAmount { get; set; }
    public bool IsPaid { get; set; }
}

[Authorize]
public class BudgetController : BaseController
{
    private readonly BudgetRepository _repo;

    public BudgetController(BudgetRepository repo)
    {
        _repo = repo;
    }

    public IActionResult Index(int? year, int? month)
    {
        int y = year ?? DateTime.Now.Year;
        int m = month ?? DateTime.Now.Month;

        int userId = GetUserId();
        var recap = _repo.GetMonthlyRecap(userId, y, m);

        ViewBag.Year = y;
        ViewBag.Month = m;
        ViewBag.MonthName = new DateTime(y, m, 1).ToString("MMMM");

        return View(recap);
    }

    [HttpPost]
    public IActionResult Save([FromBody] SaveBudgetDto dto)
    {
        int userId = GetUserId();
        _repo.SaveBudget(userId, dto.Year, dto.Month, dto.GroupType, dto.Category, dto.TargetAmount, dto.IsPaid);
        return Ok(new { success = true });
    }

    [HttpGet]
    public IActionResult ExportExcel(int? year, int? month)
    {
        ExcelPackage.License.SetNonCommercialOrganization("SpendMate");

        int y = year ?? DateTime.Now.Year;
        int m = month ?? DateTime.Now.Month;
        var monthName = new DateTime(y, m, 1).ToString("MMMM").ToUpper();

        int userId = GetUserId();
        var recap = _repo.GetMonthlyRecap(userId, y, m);

        using var package = new ExcelPackage();
        var ws = package.Workbook.Worksheets.Add("Budget");

        ws.Cells[1, 1].Value = $"INCOME : {monthName} {y}";
        ws.Cells[1, 1].Style.Font.Bold = true;

        var groups = new[] { "Fixed", "Savings", "Variable" };
        var groupTitles = new Dictionary<string, string> {
            { "Fixed", "FIXED EXPENSES" },
            { "Savings", "TABUNGAN, INVESTATION, DANA DARURAT" },
            { "Variable", "PENGELUARAN FLEKSIBLE / KEINGINAN (VARIABLE EXPENSES)" }
        };
        var groupHeaders = new Dictionary<string, string> {
            { "Fixed", "POS PENGELUARAN" },
            { "Savings", "POS TABUNGAN" },
            { "Variable", "PENGELUARAN" }
        };

        int row = 3;

        foreach (var g in groups)
        {
            var items = recap.Where(x => x.GroupType == g).ToList();

            ws.Cells[row, 1].Value = groupTitles[g];
            ws.Cells[row, 1].Style.Font.Bold = true;
            row++;

            // Headers
            ws.Cells[row, 1].Value = groupHeaders[g];
            ws.Cells[row, 2].Value = "TARGET";
            ws.Cells[row, 3].Value = "REALISASI";
            ws.Cells[row, 4].Value = "SELISIH";

            using (var range = ws.Cells[row, 1, row, 4])
            {
                range.Style.Font.Bold = true;
                range.Style.Fill.PatternType = ExcelFillStyle.Solid;
                range.Style.Fill.BackgroundColor.SetColor(Color.FromArgb(169, 208, 142)); // Green
                range.Style.Border.Top.Style = ExcelBorderStyle.Thin;
                range.Style.Border.Bottom.Style = ExcelBorderStyle.Thin;
                range.Style.Border.Left.Style = ExcelBorderStyle.Thin;
                range.Style.Border.Right.Style = ExcelBorderStyle.Thin;
            }

            row++;

            // Items
            foreach (var item in items)
            {
                var selisih = item.TargetAmount - item.ActualAmount;

                ws.Cells[row, 1].Value = item.Category;
                ws.Cells[row, 2].Value = item.TargetAmount;
                ws.Cells[row, 3].Value = item.ActualAmount;
                ws.Cells[row, 4].Value = selisih;

                ws.Cells[row, 2, row, 4].Style.Numberformat.Format = "#,##0.00";

                using (var range = ws.Cells[row, 1, row, 4])
                {
                    range.Style.Border.Top.Style = ExcelBorderStyle.Thin;
                    range.Style.Border.Bottom.Style = ExcelBorderStyle.Thin;
                    range.Style.Border.Left.Style = ExcelBorderStyle.Thin;
                    range.Style.Border.Right.Style = ExcelBorderStyle.Thin;
                }

                if (item.IsPaid)
                {
                    using (var range = ws.Cells[row, 1, row, 4])
                    {
                        range.Style.Fill.PatternType = ExcelFillStyle.Solid;
                        range.Style.Fill.BackgroundColor.SetColor(Color.FromArgb(255, 255, 0)); // Yellow
                    }
                }

                row++;
            }

            // Total
            ws.Cells[row, 1].Value = "TOTAL";
            ws.Cells[row, 2].Value = items.Sum(x => x.TargetAmount);
            ws.Cells[row, 3].Value = items.Sum(x => x.ActualAmount);
            ws.Cells[row, 4].Value = items.Sum(x => (x.TargetAmount - x.ActualAmount));

            ws.Cells[row, 2, row, 4].Style.Numberformat.Format = "#,##0.00";

            using (var range = ws.Cells[row, 1, row, 4])
            {
                range.Style.Font.Bold = true;
                range.Style.Fill.PatternType = ExcelFillStyle.Solid;
                range.Style.Fill.BackgroundColor.SetColor(Color.FromArgb(231, 230, 230)); // Light Gray
                range.Style.Border.Top.Style = ExcelBorderStyle.Thin;
                range.Style.Border.Bottom.Style = ExcelBorderStyle.Thin;
                range.Style.Border.Left.Style = ExcelBorderStyle.Thin;
                range.Style.Border.Right.Style = ExcelBorderStyle.Thin;
            }

            row += 3;
        }

        ws.Cells[row, 1].Value = "*NOTE : THE YELLOW ROW IS ALREADY PAID BY FRANKY*";
        ws.Cells[row, 1].Style.Font.Bold = true;

        ws.Cells[ws.Dimension.Address].AutoFitColumns();

        var stream = new MemoryStream();
        package.SaveAs(stream);
        stream.Position = 0;

        string fileName = $"Budget_Recap_{monthName}_{y}.xlsx";

        return File(stream, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
    }
}
