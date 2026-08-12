using System;
using System.Collections.Generic;

public interface ITransactionRepository
{
    decimal GetDailyTotal(int userId);
    IEnumerable<dynamic> GetDailySummary(int userId);
    IEnumerable<Transaction> GetTransactions(int userId, DateTime from, DateTime to);
    Transaction GetById(int id, int userId);
    void Insert(Transaction model);
    void Update(Transaction model);
    void Delete(int id, int userId);
    IEnumerable<dynamic> GetAllForExport(int userId, DateTime? from, DateTime? to);
    decimal GetTotalByType(int userId, DateTime from, DateTime to, string type);
}
