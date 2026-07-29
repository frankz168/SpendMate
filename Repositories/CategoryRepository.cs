using Dapper;
using SpendMate.Models;

public class CategoryRepository
{
    private readonly DbConnectionFactory _db;

    public CategoryRepository(DbConnectionFactory db)
    {
        _db = db;
    }

    public List<Category> GetAll()
    {
        using var conn = _db.CreateConnection();
        return conn.Query<Category>("SELECT * FROM spendmate_master_getcategories()").ToList();
    }

    public void Save(Category category)
    {
        using var conn = _db.CreateConnection();
        if (category.Id == 0)
        {
            conn.Execute("INSERT INTO categories (name, group_type, default_target, is_active) VALUES (@Name, @GroupType, @DefaultTarget, @IsActive)", category);
        }
        else
        {
            conn.Execute("UPDATE categories SET name = @Name, group_type = @GroupType, default_target = @DefaultTarget, is_active = @IsActive WHERE id = @Id", category);
        }
    }

    public void Delete(int id)
    {
        using var conn = _db.CreateConnection();
        // Soft delete by deactivating
        conn.Execute("UPDATE categories SET is_active = FALSE WHERE id = @Id", new { Id = id });
    }
}
