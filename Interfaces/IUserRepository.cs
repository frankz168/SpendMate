using System.Collections.Generic;
using SpendMate.Models;

public interface IUserRepository
{
    User? Authenticate(string username, string password);
    User? GetById(int id);
    IEnumerable<User> GetAll();
    void Create(User user, string plainPassword);
    void Update(User user, string? plainPassword);
    void Delete(int id);
}
