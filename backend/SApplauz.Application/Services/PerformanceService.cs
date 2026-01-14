using AutoMapper;
using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Services;

public class PerformanceService : IPerformanceService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IMapper _mapper;
    private readonly ICurrentUserService _currentUserService;
    private const int InstitutionTurnaroundMinutes = 30;

    public PerformanceService(ApplicationDbContext dbContext, IMapper mapper, ICurrentUserService currentUserService)
    {
        _dbContext = dbContext;
        _mapper = mapper;
        _currentUserService = currentUserService;
    }

    public async Task<PerformanceDto?> GetPerformanceByIdAsync(int id)
    {
        var query = _dbContext.Performances
            .Include(p => p.Show)
                .ThenInclude(s => s.Institution)
            .AsQueryable();

        // Filtriranje po instituciji ako korisnik ima ograničenje
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query.Where(p => p.Show.InstitutionId == userInstitutionId.Value);
        }

        var performance = await query.FirstOrDefaultAsync(p => p.Id == id);

        if (performance == null)
        {
            return null;
        }

        var dto = _mapper.Map<PerformanceDto>(performance);
        dto.ShowTitle = performance.Show.Title;
        
        // Postavi status i vizualni identitet
        EnrichPerformanceDto(dto, performance);
        
        return dto;
    }

    public async Task<List<PerformanceDto>> GetPerformancesAsync(PerformanceFilterRequest filter)
    {
        var query = _dbContext.Performances
            .Include(p => p.Show)
                .ThenInclude(s => s.Institution)
            .AsQueryable();

        // Automatsko filtriranje po instituciji korisnika (ako ima ograničenje)
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query.Where(p => p.Show.InstitutionId == userInstitutionId.Value);
        }

        // Apply filters
        if (filter.ShowId.HasValue)
        {
            query = query.Where(p => p.ShowId == filter.ShowId.Value);
        }

        if (filter.InstitutionId.HasValue)
        {
            // Ako korisnik već ima ograničenje po instituciji, provjeriti da filter nije različit
            if (userInstitutionId.HasValue && filter.InstitutionId.Value != userInstitutionId.Value)
            {
                throw new UnauthorizedAccessException("Nemate pristup podacima za tu instituciju.");
            }
            query = query.Where(p => p.Show.InstitutionId == filter.InstitutionId.Value);
        }

        if (filter.StartDate.HasValue)
        {
            var startLocal = NormalizeToAppLocalUnspecified(filter.StartDate.Value);
            query = query.Where(p => p.StartTime >= startLocal);
        }

        if (filter.EndDate.HasValue)
        {
            var endLocal = NormalizeToAppLocalUnspecified(filter.EndDate.Value);
            query = query.Where(p => p.StartTime <= endLocal);
        }

        if (filter.AvailableOnly == true)
        {
            query = query.Where(p => p.AvailableSeats > 0);
        }

        var performances = await query
            .OrderBy(p => p.StartTime)
            .Skip((filter.PageNumber - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .ToListAsync();

        return performances.Select(p =>
        {
            var dto = _mapper.Map<PerformanceDto>(p);
            dto.ShowTitle = p.Show.Title;
            
            // Postavi status i vizualni identitet
            EnrichPerformanceDto(dto, p);
            
            return dto;
        }).ToList();
    }

    public async Task<PerformanceDto> CreatePerformanceAsync(CreatePerformanceRequest request)
    {
        // Provjeri ograničenje po instituciji
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        
        // Verify show exists and load institution
        var show = await _dbContext.Shows
            .Include(s => s.Institution)
            .FirstOrDefaultAsync(s => s.Id == request.ShowId);
        
        if (show == null)
        {
            throw new KeyNotFoundException($"Show with id {request.ShowId} not found.");
        }

        // Standardizuj sve termine u bazi na APP lokalno vrijeme (Europe/Sarajevo) kao DateTimeKind.Unspecified.
        // Razlog: SQL Server vraća DateTime kao Kind=Unspecified, pa je ovo jedini konzistentan model.
        var normalizedStartLocal = NormalizeToAppLocalUnspecified(request.StartTime);

        // Provjeri da li Admin pokušava kreirati termin za tuđu instituciju
        if (userInstitutionId.HasValue && show.InstitutionId != userInstitutionId.Value)
        {
            throw new UnauthorizedAccessException("Možete kreirati termine samo za svoju instituciju.");
        }

        // Check if performance with same show and start time already exists
        var exists = await _dbContext.Performances
            .AnyAsync(p => p.ShowId == request.ShowId && p.StartTime == normalizedStartLocal);

        if (exists)
        {
            throw new InvalidOperationException($"Performance for show {request.ShowId} at {request.StartTime} already exists.");
        }

        // Zabrana preklapanja termina unutar iste institucije:
        // zauzetost = trajanje predstave + 30 min (turnaround)
        await EnsureInstitutionScheduleAvailableAsync(
            institutionId: show.InstitutionId,
            startTime: normalizedStartLocal,
            durationMinutes: show.DurationMinutes,
            excludePerformanceId: null
        );

        var performance = _mapper.Map<Performance>(request);
        performance.StartTime = normalizedStartLocal;
        performance.AvailableSeats = show.Institution.Capacity; // Initially all seats are available (equal to institution capacity)
        performance.CreatedAt = DateTime.UtcNow;

        _dbContext.Performances.Add(performance);
        await _dbContext.SaveChangesAsync();

        return await GetPerformanceByIdAsync(performance.Id) ?? throw new InvalidOperationException("Failed to retrieve created performance.");
    }

    public async Task<PerformanceDto> UpdatePerformanceAsync(int id, UpdatePerformanceRequest request)
    {
        var query = _dbContext.Performances
            .Include(p => p.Show)
                .ThenInclude(s => s.Institution)
            .AsQueryable();
        
        // Filtriranje po instituciji ako korisnik ima ograničenje
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query.Where(p => p.Show.InstitutionId == userInstitutionId.Value);
        }

        var performance = await query.FirstOrDefaultAsync(p => p.Id == id);
        if (performance == null)
        {
            throw new KeyNotFoundException($"Performance with id {id} not found.");
        }

        // Verify show exists
        var show = await _dbContext.Shows
            .Include(s => s.Institution)
            .FirstOrDefaultAsync(s => s.Id == request.ShowId);
        if (show == null)
        {
            throw new KeyNotFoundException($"Show with id {request.ShowId} not found.");
        }

        // Standardizuj sve termine u bazi na APP lokalno vrijeme (Europe/Sarajevo) kao DateTimeKind.Unspecified.
        var normalizedStartLocal = NormalizeToAppLocalUnspecified(request.StartTime);

        // Provjeri da li Admin pokušava promijeniti Show na tuđu instituciju
        if (userInstitutionId.HasValue && show.InstitutionId != userInstitutionId.Value)
        {
            throw new UnauthorizedAccessException("Možete ažurirati termine samo za svoju instituciju.");
        }

        // Check if another performance with same show and start time exists
        var exists = await _dbContext.Performances
            .AnyAsync(p => p.ShowId == request.ShowId && 
                          p.StartTime == normalizedStartLocal && 
                          p.Id != id);

        if (exists)
        {
            throw new InvalidOperationException($"Performance for show {request.ShowId} at {request.StartTime} already exists.");
        }

        // Zabrana preklapanja termina unutar iste institucije:
        // zauzetost = trajanje predstave + 30 min (turnaround)
        await EnsureInstitutionScheduleAvailableAsync(
            institutionId: show.InstitutionId,
            startTime: normalizedStartLocal,
            durationMinutes: show.DurationMinutes,
            excludePerformanceId: id
        );

        var oldStartTime = performance.StartTime;

        // Update only mutable fields (AvailableSeats is managed by OrderService during ticket purchase)
        performance.ShowId = request.ShowId;
        performance.StartTime = normalizedStartLocal;
        performance.Price = request.Price;
        performance.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync();

        // Recompute ticket status for this performance:
        // - Ako je termin pomjeren unaprijed, vrati Invalid -> NotScanned (ako nije skenirana i više nije istekla)
        // - Ako je termin pomjeren unazad, ažuriraj NotScanned -> Invalid ako je sad istekla
        await RecomputeTicketsForPerformanceAsync(performance.Id);

        return await GetPerformanceByIdAsync(performance.Id) ?? throw new InvalidOperationException("Failed to retrieve updated performance.");
    }

    private async Task RecomputeTicketsForPerformanceAsync(int performanceId)
    {
        var now = GetNowInAppTimeZone();

        var tickets = await _dbContext.Tickets
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Performance)
            .Where(t => t.OrderItem.PerformanceId == performanceId)
            .ToListAsync();

        if (!tickets.Any()) return;

        var changed = false;
        foreach (var t in tickets)
        {
            if (t.Status == TicketStatus.Scanned) continue;
            var start = t.OrderItem.Performance.StartTime;
            var isExpired = start.AddMinutes(15) < now;

            if (t.Status == TicketStatus.NotScanned && isExpired)
            {
                t.Status = TicketStatus.Invalid;
                changed = true;
            }
            else if (t.Status == TicketStatus.Invalid && !isExpired && t.ScannedAt == null)
            {
                t.Status = TicketStatus.NotScanned;
                changed = true;
            }
        }

        if (changed)
        {
            await _dbContext.SaveChangesAsync();
        }
    }

    private static DateTime GetNowInAppTimeZone()
    {
        var tz = GetAppTimeZone();
        return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
    }

    private static TimeZoneInfo GetAppTimeZone()
    {
        try { return TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo"); } catch { /* ignore */ }
        try { return TimeZoneInfo.FindSystemTimeZoneById("Central European Standard Time"); } catch { /* ignore */ }
        return TimeZoneInfo.Local;
    }

    private static DateTime NormalizeToAppLocalUnspecified(DateTime dt)
    {
        var tz = GetAppTimeZone();
        DateTime local;

        if (dt.Kind == DateTimeKind.Utc)
        {
            local = TimeZoneInfo.ConvertTimeFromUtc(dt, tz);
        }
        else if (dt.Kind == DateTimeKind.Local)
        {
            local = TimeZoneInfo.ConvertTime(dt, tz);
        }
        else
        {
            // Unspecified: tretiraj kao već uneseno u app lokalnom vremenu
            local = dt;
        }

        return DateTime.SpecifyKind(local, DateTimeKind.Unspecified);
    }

    private async Task EnsureInstitutionScheduleAvailableAsync(
        int institutionId,
        DateTime startTime,
        int durationMinutes,
        int? excludePerformanceId)
    {
        var candidateStart = NormalizeToAppLocalUnspecified(startTime);
        var candidateEnd = candidateStart.AddMinutes(durationMinutes + InstitutionTurnaroundMinutes);

        // Grubi filter: +/- 1 dan oko kandidata (sve u app lokalnom vremenu)
        var from = candidateStart.AddDays(-1);
        var to = candidateEnd.AddDays(1);

        var query = _dbContext.Performances
            .Include(p => p.Show)
            .Where(p => p.Show.InstitutionId == institutionId)
            .Where(p => p.StartTime >= from && p.StartTime <= to);

        if (excludePerformanceId.HasValue)
        {
            query = query.Where(p => p.Id != excludePerformanceId.Value);
        }

        var existing = await query.ToListAsync();
        foreach (var p in existing)
        {
            // p.StartTime je po dogovoru već app lokalno (Unspecified)
            var pStart = NormalizeToAppLocalUnspecified(p.StartTime);
            var pEnd = pStart.AddMinutes(p.Show.DurationMinutes + InstitutionTurnaroundMinutes);

            // Overlap check: [start, end) se preklapa ako start < otherEnd && otherStart < end
            if (candidateStart < pEnd && pStart < candidateEnd)
            {
                throw new InvalidOperationException("U tom terminu pozorište je već zauzeto.");
            }
        }
    }

    public async Task DeletePerformanceAsync(int id)
    {
        var query = _dbContext.Performances
            .Include(p => p.OrderItems)
            .Include(p => p.Show)
                .ThenInclude(s => s.Institution)
            .AsQueryable();
        
        // Filtriranje po instituciji ako korisnik ima ograničenje
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query.Where(p => p.Show.InstitutionId == userInstitutionId.Value);
        }

        var performance = await query.FirstOrDefaultAsync(p => p.Id == id);

        if (performance == null)
        {
            throw new KeyNotFoundException($"Performance with id {id} not found.");
        }

        // Check if performance has order items
        if (performance.OrderItems.Any())
        {
            throw new InvalidOperationException($"Cannot delete performance with id {id} because it has associated order items.");
        }

        _dbContext.Performances.Remove(performance);
        await _dbContext.SaveChangesAsync();
    }

    public async Task<bool> CheckAvailabilityAsync(int performanceId, int quantity)
    {
        var query = _dbContext.Performances.AsQueryable();
        
        // Filtriranje po instituciji ako korisnik ima ograničenje
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query
                .Include(p => p.Show)
                .Where(p => p.Show.InstitutionId == userInstitutionId.Value);
        }

        var performance = await query.FirstOrDefaultAsync(p => p.Id == performanceId);
        if (performance == null)
        {
            return false;
        }

        return performance.AvailableSeats >= quantity;
    }

    // Helper metode za status i vizualni identitet
    
    /// <summary>
    /// Obogaćuje PerformanceDto sa status informacijama i bojom
    /// </summary>
    private void EnrichPerformanceDto(PerformanceDto dto, Performance performance)
    {
        // Provjeri da li se trenutno izvodi
        dto.IsCurrentlyShowing = IsCurrentlyShowing(performance.StartTime, performance.Show.DurationMinutes);
        
        // Izračunaj status
        dto.Status = CalculateStatus(performance.AvailableSeats, dto.IsCurrentlyShowing);
        
        // Izračunaj boju statusa
        dto.StatusColor = CalculateStatusColor(performance.AvailableSeats, dto.IsCurrentlyShowing);
    }

    /// <summary>
    /// Provjerava da li se predstava trenutno izvodi
    /// </summary>
    private bool IsCurrentlyShowing(DateTime startTime, int durationMinutes)
    {
        var now = GetNowInAppTimeZone();
        var endTime = startTime.AddMinutes(durationMinutes);
        return startTime <= now && endTime >= now;
    }

    /// <summary>
    /// Izračunava status teksta za performance
    /// </summary>
    private string CalculateStatus(int availableSeats, bool isCurrentlyShowing)
    {
        if (isCurrentlyShowing)
        {
            return "Trenutno se izvodi";
        }
        
        if (availableSeats == 0)
        {
            return "Rasprodano";
        }
        
        if (availableSeats > 0 && availableSeats <= 5)
        {
            return "Posljednja mjesta";
        }
        
        return "Dostupno";
    }

    /// <summary>
    /// Izračunava boju statusa za performance
    /// </summary>
    private string CalculateStatusColor(int availableSeats, bool isCurrentlyShowing)
    {
        if (isCurrentlyShowing)
        {
            return "blue"; // Plavo za trenutno izvodenje
        }
        
        if (availableSeats == 0)
        {
            return "red"; // Crveno za rasprodano
        }
        
        if (availableSeats > 0 && availableSeats <= 5)
        {
            return "orange"; // Narandžasto za posljednja mjesta
        }
        
        return "green"; // Zeleno za dostupno
    }
}






