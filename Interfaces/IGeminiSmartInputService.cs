using System.Threading.Tasks;

public interface IGeminiSmartInputService
{
    /// <summary>
    /// Parses natural language input (e.g. "Spent $15 on coffee") into a structured Transaction object.
    /// </summary>
    Task<Transaction> ParseNaturalLanguageAsync(string input, int userId);
}
