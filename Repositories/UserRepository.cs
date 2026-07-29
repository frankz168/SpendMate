using System.Data;
using Dapper;
using Microsoft.Extensions.Logging;
using SpendMate.Models;

public class UserRepository
{
    private readonly DbConnectionFactory _db;
    private readonly ILogger<UserRepository> _logger;

    public UserRepository(DbConnectionFactory db, ILogger<UserRepository> logger)
    {
        _db = db;
        _logger = logger;
    }

    public User? Authenticate(string username, string password)
    {
        using var conn = _db.CreateConnection();
        var user = conn.QuerySingleOrDefault<User>(
            "SELECT id, name, phonenumber, username, password_hash as PasswordHash, createdate FROM users WHERE username = @Username", 
            new { Username = username });

        if (user == null)
            return null;

        if (BCrypt.Net.BCrypt.Verify(password, user.PasswordHash))
        {
            return user;
        }

        return null;
    }

    public User? GetById(int id)
    {
        using var conn = _db.CreateConnection();
        return conn.QuerySingleOrDefault<User>(
            "SELECT id, name, phonenumber, username, password_hash as PasswordHash, createdate FROM users WHERE id = @Id", 
            new { Id = id });
    }
}
