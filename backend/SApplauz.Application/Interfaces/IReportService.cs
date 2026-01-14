using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface IReportService
{
    Task<SalesReportDto> GetSalesReportAsync(ReportFilterRequest filter);
    Task<PopularityReportDto> GetPopularityReportAsync(ReportFilterRequest filter);
}






