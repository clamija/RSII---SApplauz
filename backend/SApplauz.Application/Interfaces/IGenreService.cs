using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface IGenreService
{
    Task<GenreDto?> GetGenreByIdAsync(int id);
    Task<List<GenreDto>> GetAllGenresAsync();
    Task<GenreDto> CreateGenreAsync(CreateGenreRequest request);
    Task<GenreDto> UpdateGenreAsync(int id, UpdateGenreRequest request);
    Task DeleteGenreAsync(int id);
}






