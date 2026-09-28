using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class InsightsController : BaseController
{
    private readonly IFinancialInsightService _insightService;
    private readonly ILogger<InsightsController> _logger;

    public InsightsController(IFinancialInsightService insightService, ILogger<InsightsController> logger)
    {
        _insightService = insightService;
        _logger = logger;
    }

    [HttpGet("monthly")]
    public async Task<IActionResult> GetMonthlyInsights()
    {
        try
        {
            var data = await _insightService.GetMonthlyInsightsAsync(GetUserId());
            return Ok(data);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to fetch monthly insights.");
            return StatusCode(500, "An internal server error occurred while retrieving insights.");
        }
    }
}
