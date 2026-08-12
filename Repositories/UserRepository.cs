using System.Data;
using Dapper;
using Microsoft.Extensions.Logging;
using SpendMate.Models;

public class UserRepository : IUserRepository
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
            "SELECT * FROM spendmate_user_getbyusername(@Username)", 
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
            "SELECT * FROM spendmate_user_getbyid(@Id)", 
            new { Id = id });
    }

    public IEnumerable<User> GetAll()
    {
        using var conn = _db.CreateConnection();
        return conn.Query<User>(
            "SELECT * FROM spendmate_user_getall()"
        );
    }

    public void Create(User user, string plainPassword)
    {
        using var conn = _db.CreateConnection();
        string hash = BCrypt.Net.BCrypt.HashPassword(plainPassword);
        
        conn.Execute(
            "SELECT spendmate_user_insert(@Name, @PhoneNumber, @Username, @PasswordHash)",
            new { 
                Name = user.Name ?? "", 
                PhoneNumber = user.PhoneNumber ?? "", 
                Username = user.Username, 
                PasswordHash = hash 
            }
        );
    }

    public void Update(User user, string? plainPassword)
    {
        using var conn = _db.CreateConnection();
        
        if (!string.IsNullOrEmpty(plainPassword))
        {
            string hash = BCrypt.Net.BCrypt.HashPassword(plainPassword);
            conn.Execute(
                "SELECT spendmate_user_update(@Id, @Name, @PhoneNumber, @Username, @PasswordHash)",
                new { 
                    Id = user.Id,
                    Name = user.Name ?? "", 
                    PhoneNumber = user.PhoneNumber ?? "", 
                    Username = user.Username, 
                    PasswordHash = hash 
                }
            );
        }
        else
        {
            conn.Execute(
                "SELECT spendmate_user_update(@Id, @Name, @PhoneNumber, @Username, NULL)",
                new { 
                    Id = user.Id,
                    Name = user.Name ?? "", 
                    PhoneNumber = user.PhoneNumber ?? "", 
                    Username = user.Username 
                }
            );
        }
    }

    public void Delete(int id)
    {
        using var conn = _db.CreateConnection();
        conn.Execute("SELECT spendmate_user_delete(@Id)", new { Id = id });
    }
}
