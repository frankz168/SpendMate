using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

public class GeminiSmartInputService : IGeminiSmartInputService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<GeminiSmartInputService> _logger;

    public GeminiSmartInputService(HttpClient httpClient, IConfiguration configuration, ILogger<GeminiSmartInputService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<Transaction> ParseNaturalLanguageAsync(string input, int userId)
    {
        _logger.LogInformation("Parsing natural language input via Gemini for UserId: {UserId}", userId);

        var apiKey = _configuration["GeminiSettings:ApiKey"];
        var endpoint = _configuration["GeminiSettings:Endpoint"];

        if (string.IsNullOrEmpty(apiKey) || string.IsNullOrEmpty(endpoint))
        {
            throw new Exception("Gemini API configuration is missing.");
        }

        // Construct the prompt telling Gemini to return JSON matching the Transaction object
        var prompt = $@"
You are a smart financial assistant. Analyze the following natural language input and extract transaction details into JSON format.
Rules:
- 'Type' must be exactly 'Income', 'Expense', or 'Transfer'.
- 'Amount' must be a decimal number (without currency symbols).
- 'Category' should be a short string like 'Food', 'Transport', 'Utilities', 'Salary', 'Shopping', etc.
- 'Note' should capture the context (e.g. 'Lunch at McDonalds').
- 'Destination' is optional, use it if transferring money to an account/person.

Input: ""{input}""

Return ONLY raw JSON in this exact structure, with no markdown formatting:
{{
  ""Type"": ""Expense"",
  ""Amount"": 0.0,
  ""Category"": """",
  ""Note"": """",
  ""Destination"": """"
}}
";

        var payload = new
        {
            contents = new[]
            {
                new
                {
                    parts = new[]
                    {
                        new { text = prompt }
                    }
                }
            }
        };

        var jsonPayload = JsonSerializer.Serialize(payload);
        var content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync($"{endpoint}?key={apiKey}", content);
        
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadAsStringAsync();
            _logger.LogError("Gemini API Error: {Error}", error);
            throw new Exception("Failed to parse input with Gemini API.");
        }

        var responseContent = await response.Content.ReadAsStringAsync();
        
        // Basic parsing of Gemini response (assuming it follows our instructions)
        using var jsonDocument = JsonDocument.Parse(responseContent);
        var root = jsonDocument.RootElement;
        
        var textResult = root
            .GetProperty("candidates")[0]
            .GetProperty("content")
            .GetProperty("parts")[0]
            .GetProperty("text")
            .GetString();

        // Clean up potential markdown formatting if Gemini didn't listen
        if (textResult.StartsWith("```json"))
        {
            textResult = textResult.Replace("```json", "").Replace("```", "").Trim();
        }

        var transaction = JsonSerializer.Deserialize<Transaction>(textResult, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (transaction != null)
        {
            transaction.UserId = userId;
            transaction.Createdate = DateTime.Now; // Default to now, or let Gemini parse it later!
        }

        return transaction;
    }
}
