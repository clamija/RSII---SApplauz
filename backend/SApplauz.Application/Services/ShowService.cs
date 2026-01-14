using AutoMapper;
using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Services;

public class ShowService : IShowService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IMapper _mapper;
    private readonly ICurrentUserService _currentUserService;

    public ShowService(ApplicationDbContext dbContext, IMapper mapper, ICurrentUserService currentUserService)
    {
        _dbContext = dbContext;
        _mapper = mapper;
        _currentUserService = currentUserService;
    }

    public async Task<ShowDto?> GetShowByIdAsync(int id)
    {
        var query = _dbContext.Shows
            .Include(s => s.Institution)
            .Include(s => s.Genre)
            .Include(s => s.Reviews.Where(r => r.IsVisible))
            .Include(s => s.Performances)
            .AsQueryable();

        var show = await query.FirstOrDefaultAsync(s => s.Id == id);

        if (show == null)
        {
            return null;
        }

        var dto = _mapper.Map<ShowDto>(show);
        dto.InstitutionName = show.Institution.Name;
        dto.GenreId = show.GenreId;
        dto.GenreName = show.Genre.Name;
        dto.ResolvedImagePath = !string.IsNullOrWhiteSpace(show.ImagePath)
            ? show.ImagePath
            : (!string.IsNullOrWhiteSpace(show.Institution.ImagePath) ? show.Institution.ImagePath : "/images/default.png");
        
        if (show.Reviews.Any())
        {
            dto.AverageRating = show.Reviews.Average(r => r.Rating);
            dto.ReviewsCount = show.Reviews.Count;
        }
        
        dto.PerformancesCount = show.Performances.Count;
        
        return dto;
    }

    public async Task<ShowListResponse> GetShowsAsync(ShowFilterRequest filter)
    {
        return await GetShowsInternalAsync(filter, applyInstitutionRestriction: true);
    }

    public async Task<ShowListResponse> GetShowsPublicAsync(ShowFilterRequest filter)
    {
        // Public repertor: NEMA automatskog ograničenja po instituciji za Admin/Blagajnik
        return await GetShowsInternalAsync(filter, applyInstitutionRestriction: false);
    }

    private async Task<ShowListResponse> GetShowsInternalAsync(ShowFilterRequest filter, bool applyInstitutionRestriction)
    {
        var query = _dbContext.Shows
            .Include(s => s.Institution)
            .Include(s => s.Genre)
            .Include(s => s.Reviews.Where(r => r.IsVisible))
            .AsQueryable();

        int? userInstitutionId = null;
        if (applyInstitutionRestriction)
        {
            userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
            if (userInstitutionId.HasValue)
            {
                query = query.Where(s => s.InstitutionId == userInstitutionId.Value);
            }
        }

        // Apply filters
        if (filter.InstitutionId.HasValue)
        {
            if (applyInstitutionRestriction && userInstitutionId.HasValue && filter.InstitutionId.Value != userInstitutionId.Value)
            {
                throw new UnauthorizedAccessException("Nemate pristup podacima za tu instituciju.");
            }
            query = query.Where(s => s.InstitutionId == filter.InstitutionId.Value);
        }

        if (filter.GenreId.HasValue)
        {
            query = query.Where(s => s.GenreId == filter.GenreId.Value);
        }

        if (!string.IsNullOrWhiteSpace(filter.SearchTerm))
        {
            var searchTerm = filter.SearchTerm.ToLower();
            query = query.Where(s => s.Title.ToLower().Contains(searchTerm));
        }

        if (filter.IsActive.HasValue)
        {
            query = query.Where(s => s.IsActive == filter.IsActive.Value);
        }

        var totalCount = await query.CountAsync();

        var shows = await query
            .OrderBy(s => s.Title)
            .Skip((filter.PageNumber - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .ToListAsync();

        var showDtos = shows.Select(show =>
        {
            var dto = _mapper.Map<ShowDto>(show);
            dto.InstitutionName = show.Institution.Name;
            dto.GenreId = show.GenreId;
            dto.GenreName = show.Genre.Name;
            dto.ResolvedImagePath = !string.IsNullOrWhiteSpace(show.ImagePath)
                ? show.ImagePath
                : (!string.IsNullOrWhiteSpace(show.Institution.ImagePath) ? show.Institution.ImagePath : "/images/default.png");

            if (show.Reviews.Any())
            {
                dto.AverageRating = show.Reviews.Average(r => r.Rating);
                dto.ReviewsCount = show.Reviews.Count;
            }

            dto.PerformancesCount = show.Performances.Count;
            return dto;
        }).ToList();

        return new ShowListResponse
        {
            Shows = showDtos,
            TotalCount = totalCount,
            PageNumber = filter.PageNumber,
            PageSize = filter.PageSize
        };
    }

    public async Task<ShowDto> CreateShowAsync(CreateShowRequest request)
    {
        // Provjeri ograničenje po instituciji
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue && request.InstitutionId != userInstitutionId.Value)
        {
            throw new UnauthorizedAccessException("Možete kreirati predstave samo za svoju instituciju.");
        }

        // Verify institution exists
        var institution = await _dbContext.Institutions.FindAsync(request.InstitutionId);
        if (institution == null)
        {
            throw new KeyNotFoundException($"Institution with id {request.InstitutionId} not found.");
        }

        // Verify genre exists
        var genre = await _dbContext.Genres.FindAsync(request.GenreId);
        if (genre == null)
        {
            throw new KeyNotFoundException($"Genre with id {request.GenreId} not found.");
        }

        var show = _mapper.Map<Show>(request);
        show.CreatedAt = DateTime.UtcNow;

        _dbContext.Shows.Add(show);
        await _dbContext.SaveChangesAsync();

        return await GetShowByIdAsync(show.Id) ?? throw new InvalidOperationException("Failed to retrieve created show.");
    }

    public async Task<ShowDto> UpdateShowAsync(int id, UpdateShowRequest request)
    {
        var query = _dbContext.Shows.AsQueryable();
        
        // Filtriranje po instituciji ako korisnik ima ograničenje
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query.Where(s => s.InstitutionId == userInstitutionId.Value);
        }

        var show = await query.FirstOrDefaultAsync(s => s.Id == id);

        if (show == null)
        {
            throw new KeyNotFoundException($"Show with id {id} not found.");
        }

        // Provjeri da li Admin pokušava promijeniti instituciju
        if (userInstitutionId.HasValue && request.InstitutionId != userInstitutionId.Value)
        {
            throw new UnauthorizedAccessException("Možete ažurirati predstave samo za svoju instituciju.");
        }

        // Verify institution exists
        var institution = await _dbContext.Institutions.FindAsync(request.InstitutionId);
        if (institution == null)
        {
            throw new KeyNotFoundException($"Institution with id {request.InstitutionId} not found.");
        }

        // Verify genre exists
        var genre = await _dbContext.Genres.FindAsync(request.GenreId);
        if (genre == null)
        {
            throw new KeyNotFoundException($"Genre with id {request.GenreId} not found.");
        }

        // Update show properties
        show.Title = request.Title;
        show.Description = request.Description;
        show.DurationMinutes = request.DurationMinutes;
        show.InstitutionId = request.InstitutionId;
        show.GenreId = request.GenreId;
        show.ImagePath = request.ImagePath;
        show.IsActive = request.IsActive;
        show.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync();

        return await GetShowByIdAsync(show.Id) ?? throw new InvalidOperationException("Failed to retrieve updated show.");
    }

    public async Task DeleteShowAsync(int id)
    {
        var query = _dbContext.Shows
            .Include(s => s.Performances)
            .Include(s => s.Reviews)
            .AsQueryable();
        
        // Filtriranje po instituciji ako korisnik ima ograničenje
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query.Where(s => s.InstitutionId == userInstitutionId.Value);
        }

        var show = await query.FirstOrDefaultAsync(s => s.Id == id);

        if (show == null)
        {
            throw new KeyNotFoundException($"Show with id {id} not found.");
        }

        // Ako postoje povezani termini, ne radimo hard-delete (FK/istorija),
        // već "soft delete" (deaktivacija) da se predstava više ne prikazuje u aktivnim listama.
        if (show.Performances.Any())
        {
            show.IsActive = false;
            show.UpdatedAt = DateTime.UtcNow;
            await _dbContext.SaveChangesAsync();
            return;
        }

        _dbContext.Shows.Remove(show);
        await _dbContext.SaveChangesAsync();
    }
}






