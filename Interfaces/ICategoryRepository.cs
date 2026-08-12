using System.Collections.Generic;
using SpendMate.Models;

public interface ICategoryRepository
{
    List<Category> GetAll();
    void Save(Category category);
    void Delete(int id);
}
