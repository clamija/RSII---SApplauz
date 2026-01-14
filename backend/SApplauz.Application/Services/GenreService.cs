using AutoMapper;
using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Services;

public class GenreService : IGenreService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IMapper _mapper;

    public GenreService(ApplicationDbContext dbContext, IMapper mapper)
    {
        _dbContext = dbContext;
        _mapper = mapper;
    }

    public async Task<GenreDto?> GetGenreByIdAsync(int id)
    {
        var genre = await _dbContext.Genres.FindAsync(id);
        return genre == null ? null : _mapper.Map<GenreDto>(genre);
    }

    public async Task<List<GenreDto>> GetAllGenresAsync()
    {
        var genres = await _dbContext.Genres
            .OrderBy(g => g.Name)
            .ToListAsync();

        return _mapper.Map<List<GenreDto>>(genres);
    }

    public async Task<GenreDto> CreateGenreAsync(CreateGenreRequest request)
    {
        // Check if genre with same name already exists
        var exists = await _dbContext.Genres
            .AnyAsync(g => g.Name.ToLower() == request.Name.ToLower());

        if (exists)
        {
            throw new InvalidOperationException($"Genre with name '{request.Name}' already exists.");
        }

        var genre = _mapper.Map<Genre>(request);
        genre.CreatedAt = DateTime.UtcNow;

        _dbContext.Genres.Add(genre);
        await _dbContext.SaveChangesAsync();

        return _mapper.Map<GenreDto>(genre);
    }

    public async Task<GenreDto> UpdateGenreAsync(int id, UpdateGenreRequest request)
    {
        var genre = await _dbContext.Genres.FindAsync(id);
        if (genre == null)
        {
            throw new KeyNotFoundException($"Genre with id {id} not found.");
        }

        // Check if another genre with same name exists
        var exists = await _dbContext.Genres
            .AnyAsync(g => g.Name.ToLower() == request.Name.ToLower() && g.Id != id);

        if (exists)
        {
            throw new InvalidOperationException($"Genre with name '{request.Name}' already exists.");
        }

        genre.Name = request.Name;
        await _dbContext.SaveChangesAsync();

        return _mapper.Map<GenreDto>(genre);
    }

    public async Task DeleteGenreAsync(int id)
    {
        var genre = await _dbContext.Genres
            .Include(g => g.Shows)
            .FirstOrDefaultAsync(g => g.Id == id);

        if (genre == null)
        {
            throw new KeyNotFoundException($"Genre with id {id} not found.");
        }

        // Check if genre is used in any shows
        var showsCount = genre.Shows.Count;
        if (showsCount > 0)
        {
            throw new InvalidOperationException($"Ne možete obrisati žanr jer se koristi u {showsCount} {(showsCount == 1 ? "predstavi" : "predstava")}.");
        }

        _dbContext.Genres.Remove(genre);
        await _dbContext.SaveChangesAsync();
    }
}






