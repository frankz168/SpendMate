using Dapper;

public class ConfigRepository
{
    private readonly DbConnectionFactory _db;

    public ConfigRepository(DbConnectionFactory db)
    {
        _db = db;
    }

    public string GetString(string key, string defaultValue = "")
    {
        using var conn = _db.CreateConnection();
        var value = conn.QueryFirstOrDefault<string>(
            "SELECT get_config_value(@Key::VARCHAR);",
            new { Key = key }
        );
        return string.IsNullOrEmpty(value) ? defaultValue : value;
    }

    public decimal GetDecimal(string key, decimal defaultValue = 0)
    {
        var value = GetString(key);
        if (decimal.TryParse(value, out decimal result))
        {
            return result;
        }
        return defaultValue;
    }

    public int GetInt(string key, int defaultValue = 0)
    {
        var value = GetString(key);
        if (int.TryParse(value, out int result))
        {
            return result;
        }
        return defaultValue;
    }

    public TimeSpan GetTimeSpan(string key, TimeSpan defaultValue)
    {
        var value = GetString(key);
        if (TimeSpan.TryParse(value, out TimeSpan result))
        {
            return result;
        }
        return defaultValue;
    }
    
    public List<string> GetStringList(string key, List<string>? defaultValue = null)
    {
        var value = GetString(key);
        if (!string.IsNullOrEmpty(value))
        {
            return value.Split(',').Select(x => x.Trim()).ToList();
        }
        return defaultValue ?? new List<string>();
    }
}
