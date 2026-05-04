public class ExpenseService
{
    private readonly ExpenseRepository _repo;

    public ExpenseService(ExpenseRepository repo)
    {
        _repo = repo;
    }

    public object GetDashboard(int userId)
    {
        var total = _repo.GetDailyTotal(userId);
        var summary = _repo.GetDailySummary(userId);
        var expenses = _repo.GetTodayExpenses(userId);

        return new
        {
            total,
            summary,
            expenses
        };
    }

    public Expense GetById(int id, int userId)
    {
        return _repo.GetById(id, userId);
    }

    public void Save(Expense model)
    {
        if (model.Id == 0)
            _repo.Insert(model);
        else
            _repo.Update(model);
    }

    public void Delete(int id, int userId)
    {
        _repo.Delete(id, userId);
    }

    public IEnumerable<dynamic> Export(int userId)
    {
        return _repo.GetAllForExport(userId);
    }
}