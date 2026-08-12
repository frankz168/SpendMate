using System;
using System.Collections.Generic;

public interface IConfigRepository
{
    string GetString(string key, string defaultValue = "");
    void SetString(string key, string value);
    decimal GetDecimal(string key, decimal defaultValue = 0);
    int GetInt(string key, int defaultValue = 0);
    TimeSpan GetTimeSpan(string key, TimeSpan defaultValue);
    List<string> GetStringList(string key, List<string>? defaultValue = null);
}
