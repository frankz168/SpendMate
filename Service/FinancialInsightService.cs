using System;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

public class FinancialInsightService : IFinancialInsightService
{
    private readonly ITransactionRepository _repo;
    private readonly ICacheService _cache;
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;
    private readonly ILogger<FinancialInsightService> _logger;

    public FinancialInsightService(
        ITransactionRepository repo,
        ICacheService cache,
        HttpClient httpClient,
        IConfiguration config,
        ILogger<FinancialInsightService> logger)
    {
        _repo = repo;
        _cache = cache;
        _httpClient = httpClient;
        _config = config;
        _logger = logger;
        _httpClient.Timeout = TimeSpan.FromSeconds(20); // Resilient timeout
    }

    public async Task<FinancialInsightDto> GetMonthlyInsightsAsync(int userId)
    {
        string cacheKey = $"FinancialInsights_Monthly_{userId}_{DateTime.Now:yyyyMM}";

        // 1. Check Redis Cache
        try
        {
            var cachedInsight = await _cache.GetAsync<FinancialInsightDto>(cacheKey);
            if (cachedInsight != null)
            {
                _logger.LogInformation("Returning AI insights from Redis cache for user {UserId}", userId);
                return cachedInsight;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Redis cache failure. Gracefully falling back to generating new insights.");
        }

        // 2. Fetch Aggregated Data from SQL Server
        var now = DateTime.Now;
        var startOfMonth = new DateTime(now.Year, now.Month, 1);
        
        var expenses = _repo.GetTransactions(userId, startOfMonth, now)
                            .Where(t => t.Type.Equals("Expense", StringComparison.OrdinalIgnoreCase))
                            .ToList();

        if (!expenses.Any())
        {
            return new FinancialInsightDto 
            { 
                Insights = "You have no expenses recorded for this month yet. Keep up the good work or start tracking your spending!", 
                GeneratedAt = DateTime.Now 
            };
        }

        var categorySummary = expenses
            .GroupBy(t => t.Category)
            .Select(g => new { Category = g.Key, Total = g.Sum(x => x.Amount) })
            .ToList();

        var summaryJson = JsonSerializer.Serialize(categorySummary);

        // 3. AI Analysis via Gemini
        string aiInsightText;
        
        try
        {
            var apiKey = _config["GeminiSettings:ApiKey"];
            var endpoint = _config["GeminiSettings:Endpoint"];

            var prompt = $@"
You are a senior financial advisor. I will provide a user's spending summary for the current month in JSON format (Category and Total Amount).
Write a 3-paragraph financial advice/insight based on this data.
Paragraph 1: Summarize their spending habits.
Paragraph 2: Identify any potential areas of concern or high spending.
Paragraph 3: Give actionable advice for next month.

Do not use markdown formatting.

Spending Data:
{summaryJson}";

            var payload = new { contents = new[] { new { parts = new[] { new { text = prompt } } } } };
            var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{endpoint}?key={apiKey}", content);
            response.EnsureSuccessStatusCode();

            var responseString = await response.Content.ReadAsStringAsync();
            using var jsonDoc = JsonDocument.Parse(responseString);
            
            aiInsightText = jsonDoc.RootElement
                .GetProperty("candidates")[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString()?.Trim() ?? "AI returned empty insights.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to call Gemini API for insights.");
            // Graceful degradation
            var highestCategory = categorySummary.OrderByDescending(x => x.Total).FirstOrDefault()?.Category;
            aiInsightText = $"Your top spending category this month is {highestCategory}. Unfortunately, our AI advisor is currently unavailable to provide deep insights due to a network error.";
        }

        var result = new FinancialInsightDto
        {
            Insights = aiInsightText,
            GeneratedAt = DateTime.Now
        };

        // 4. Save to Redis Cache (24 hours)
        try
        {
            await _cache.SetAsync(cacheKey, result, TimeSpan.FromHours(24));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to save AI insights to Redis cache. It will be regenerated next time.");
        }

        return result;
    }
}
