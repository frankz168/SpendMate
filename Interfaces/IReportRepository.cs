using System.Collections.Generic;

public interface IReportRepository
{
    List<ReportItem> GetReportData(string type, int userId);
}
