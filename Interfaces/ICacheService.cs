using System;
using System.Threading.Tasks;

public interface ICacheService
{
    /// <summary>
    /// Retrieves an item from the cache.
    /// </summary>
    Task<T> GetAsync<T>(string key);

    /// <summary>
    /// Sets an item in the cache.
    /// </summary>
    Task SetAsync<T>(string key, T value, TimeSpan? absoluteExpireTime = null);

    /// <summary>
    /// Removes an item from the cache.
    /// </summary>
    Task RemoveAsync(string key);
}
