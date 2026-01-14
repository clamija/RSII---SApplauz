using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface IShowService
{
    Task<ShowDto?> GetShowByIdAsync(int id);
    Task<ShowListResponse> GetShowsAsync(ShowFilterRequest filter);
    Task<ShowListResponse> GetShowsPublicAsync(ShowFilterRequest filter);
    Task<ShowDto> CreateShowAsync(CreateShowRequest request);
    Task<ShowDto> UpdateShowAsync(int id, UpdateShowRequest request);
    Task DeleteShowAsync(int id);
}






