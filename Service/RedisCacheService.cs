using System;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

public class RedisCacheService : ICacheService
{
    private readonly IDistributedCache _cache;
    private readonly ILogger<RedisCacheService> _logger;

    // Fast timeout for cache operations to avoid blocking page loads if Redis is slow/down
    private static readonly TimeSpan DefaultTimeout = TimeSpan.FromMilliseconds(500);

    // Circuit breaker state to fast-fail subsequent requests when Redis is unavailable
    private static readonly TimeSpan CircuitBreakerDuration = TimeSpan.FromSeconds(30);
    private static DateTime _circuitResetTimeUtc = DateTime.MinValue;
    private static bool _isCircuitOpen = false;
    private static readonly object _circuitLock = new();

    public RedisCacheService(IDistributedCache cache, ILogger<RedisCacheService> logger)
    {
        _cache = cache;
        _logger = logger;
    }

    private bool IsCircuitOpen()
    {
        if (!_isCircuitOpen) return false;

        lock (_circuitLock)
        {
            if (_isCircuitOpen && DateTime.UtcNow >= _circuitResetTimeUtc)
            {
                // Half-open: allow a trial request
                _isCircuitOpen = false;
                return false;
            }
            return _isCircuitOpen;
        }
    }

    private void TripCircuit(Exception ex)
    {
        lock (_circuitLock)
        {
            _isCircuitOpen = true;
            _circuitResetTimeUtc = DateTime.UtcNow.Add(CircuitBreakerDuration);
        }
        _logger.LogWarning("Redis cache unavailable ({Message}). Bypassing Redis for {Duration}s.", ex.Message, CircuitBreakerDuration.TotalSeconds);
    }

    public async Task<T> GetAsync<T>(string key)
    {
        if (IsCircuitOpen())
        {
            return default;
        }

        try
        {
            using var cts = new CancellationTokenSource(DefaultTimeout);
            var cachedData = await _cache.GetStringAsync(key, cts.Token);
            if (string.IsNullOrEmpty(cachedData))
            {
                return default;
            }

            return JsonSerializer.Deserialize<T>(cachedData);
        }
        catch (Exception ex)
        {
            TripCircuit(ex);
            return default;
        }
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? absoluteExpireTime = null)
    {
        if (IsCircuitOpen())
        {
            return;
        }

        try
        {
            var options = new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = absoluteExpireTime ?? TimeSpan.FromMinutes(60)
            };

            var serializedData = JsonSerializer.Serialize(value);
            using var cts = new CancellationTokenSource(DefaultTimeout);
            await _cache.SetStringAsync(key, serializedData, options, cts.Token);
        }
        catch (Exception ex)
        {
            TripCircuit(ex);
        }
    }

    public async Task RemoveAsync(string key)
    {
        if (IsCircuitOpen())
        {
            return;
        }

        try
        {
            using var cts = new CancellationTokenSource(DefaultTimeout);
            await _cache.RemoveAsync(key, cts.Token);
        }
        catch (Exception ex)
        {
            TripCircuit(ex);
        }
    }
}

