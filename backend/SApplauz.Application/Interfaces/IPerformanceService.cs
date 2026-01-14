using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface IPerformanceService
{
    Task<PerformanceDto?> GetPerformanceByIdAsync(int id);
    Task<List<PerformanceDto>> GetPerformancesAsync(PerformanceFilterRequest filter);
    Task<PerformanceDto> CreatePerformanceAsync(CreatePerformanceRequest request);
    Task<PerformanceDto> UpdatePerformanceAsync(int id, UpdatePerformanceRequest request);
    Task DeletePerformanceAsync(int id);
    Task<bool> CheckAvailabilityAsync(int performanceId, int quantity);
}






