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
        return await GetShowsInternalAsync(filter, applyInstitutionRestriction: false);
    }

    private async Task<ShowListResponse> GetShowsInternalAsync(ShowFilterRequest filter, bool applyInstitutionRestriction)
    {
        // IMPORTANT:
        // Ne radimo paginaciju direktno nad query-jem sa Include(Reviews) jer join može duplirati redove
        // i poremetiti Count/Skip/Take (što je uzrokovalo "Stranica 1 od 2" sa samo par prikazanih predstava).
        var baseQuery = _dbContext.Shows.AsQueryable();

        int? userInstitutionId = null;
        if (applyInstitutionRestriction)
        {
            userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
            if (userInstitutionId.HasValue)
            {
                baseQuery = baseQuery.Where(s => s.InstitutionId == userInstitutionId.Value);
            }
        }

        if (filter.InstitutionId.HasValue)
        {
            if (applyInstitutionRestriction && userInstitutionId.HasValue && filter.InstitutionId.Value != userInstitutionId.Value)
            {
                throw new UnauthorizedAccessException("Nemate pristup podacima za tu instituciju.");
            }
            baseQuery = baseQuery.Where(s => s.InstitutionId == filter.InstitutionId.Value);
        }

        if (filter.GenreId.HasValue)
        {
            baseQuery = baseQuery.Where(s => s.GenreId == filter.GenreId.Value);
        }

        if (!string.IsNullOrWhiteSpace(filter.SearchTerm))
        {
            var searchTerm = filter.SearchTerm.ToLower();
            baseQuery = baseQuery.Where(s => s.Title.ToLower().Contains(searchTerm));
        }

        if (filter.IsActive.HasValue)
        {
            baseQuery = baseQuery.Where(s => s.IsActive == filter.IsActive.Value);
        }

        var totalCount = await baseQuery.CountAsync();

        var showIds = await baseQuery
            .OrderBy(s => s.Title)
            .Skip((filter.PageNumber - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .Select(s => s.Id)
            .ToListAsync();

        var shows = await _dbContext.Shows
            .Where(s => showIds.Contains(s.Id))
            .Include(s => s.Institution)
            .Include(s => s.Genre)
            .Include(s => s.Reviews.Where(r => r.IsVisible))
            .AsNoTracking()
            .ToListAsync();

        // Očuvaj isti redoslijed kao ID lista (paging order)
        var showById = shows.ToDictionary(s => s.Id);
        var orderedShows = showIds.Where(showById.ContainsKey).Select(id => showById[id]).ToList();

        var showDtos = orderedShows.Select(show =>
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
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue && request.InstitutionId != userInstitutionId.Value)
        {
            throw new UnauthorizedAccessException("Možete kreirati predstave samo za svoju instituciju.");
        }

        var institution = await _dbContext.Institutions.FindAsync(request.InstitutionId);
        if (institution == null)
        {
            throw new KeyNotFoundException($"Institution with id {request.InstitutionId} not found.");
        }

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

        if (userInstitutionId.HasValue && request.InstitutionId != userInstitutionId.Value)
        {
            throw new UnauthorizedAccessException("Možete ažurirati predstave samo za svoju instituciju.");
        }

        var institution = await _dbContext.Institutions.FindAsync(request.InstitutionId);
        if (institution == null)
        {
            throw new KeyNotFoundException($"Institution with id {request.InstitutionId} not found.");
        }

        var genre = await _dbContext.Genres.FindAsync(request.GenreId);
        if (genre == null)
        {
            throw new KeyNotFoundException($"Genre with id {request.GenreId} not found.");
        }

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






