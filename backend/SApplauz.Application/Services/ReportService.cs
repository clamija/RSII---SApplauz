using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Services;

public class ReportService : IReportService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUserService;

    public ReportService(ApplicationDbContext dbContext, ICurrentUserService currentUserService)
    {
        _dbContext = dbContext;
        _currentUserService = currentUserService;
    }

    public async Task<SalesReportDto> GetSalesReportAsync(ReportFilterRequest filter)
    {
        var startDate = filter.StartDate ?? DateTime.UtcNow.AddMonths(-1);
        var endDate = filter.EndDate ?? DateTime.UtcNow;

        var query = _dbContext.Orders
            .Include(o => o.Institution)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Tickets)
            .Where(o => o.Status == OrderStatus.Paid &&
                       o.CreatedAt >= startDate &&
                       o.CreatedAt <= endDate);

        // Automatsko filtriranje po instituciji korisnika (ako ima ograničenje)
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query.Where(o => o.InstitutionId == userInstitutionId.Value);
        }

        // Apply additional filters
        if (filter.InstitutionId.HasValue)
        {
            // Ako korisnik već ima ograničenje po instituciji, provjeriti da filter nije različit
            if (userInstitutionId.HasValue && filter.InstitutionId.Value != userInstitutionId.Value)
            {
                throw new UnauthorizedAccessException("Nemate pristup izvještajima za tu instituciju.");
            }
            query = query.Where(o => o.InstitutionId == filter.InstitutionId.Value);
        }

        var orders = await query.ToListAsync();

        // Calculate totals
        var totalRevenue = orders.Sum(o => o.TotalAmount);
        var totalOrders = orders.Count;
        var totalTicketsSold = orders
            .SelectMany(o => o.OrderItems)
            .SelectMany(oi => oi.Tickets)
            .Count(t => t.Status == TicketStatus.NotScanned || t.Status == TicketStatus.Scanned);

        // Sales by Institution
        var salesByInstitution = orders
            .GroupBy(o => new { o.InstitutionId, o.Institution.Name })
            .Select(g => new SalesByInstitutionDto
            {
                InstitutionId = g.Key.InstitutionId,
                InstitutionName = g.Key.Name,
                Revenue = g.Sum(o => o.TotalAmount),
                OrdersCount = g.Count(),
                TicketsSold = g.SelectMany(o => o.OrderItems)
                    .SelectMany(oi => oi.Tickets)
                    .Count(t => t.Status == TicketStatus.NotScanned || t.Status == TicketStatus.Scanned)
            })
            .OrderByDescending(s => s.Revenue)
            .ToList();

        // Sales by Show
        var salesByShow = orders
            .SelectMany(o => o.OrderItems)
            .GroupBy(oi => new { oi.Performance.ShowId, oi.Performance.Show.Title })
            .Select(g => new SalesByShowDto
            {
                ShowId = g.Key.ShowId,
                ShowTitle = g.Key.Title,
                Revenue = g.Sum(oi => oi.UnitPrice * oi.Quantity),
                OrdersCount = g.Select(oi => oi.OrderId).Distinct().Count(),
                TicketsSold = g.SelectMany(oi => oi.Tickets)
                    .Count(t => t.Status == TicketStatus.NotScanned || t.Status == TicketStatus.Scanned)
            })
            .OrderByDescending(s => s.Revenue)
            .ToList();

        // Daily Sales
        var dailySales = orders
            .GroupBy(o => o.CreatedAt.Date)
            .Select(g => new DailySalesDto
            {
                Date = g.Key,
                Revenue = g.Sum(o => o.TotalAmount),
                OrdersCount = g.Count(),
                TicketsSold = g.SelectMany(o => o.OrderItems)
                    .SelectMany(oi => oi.Tickets)
                    .Count(t => t.Status == TicketStatus.NotScanned || t.Status == TicketStatus.Scanned)
            })
            .OrderBy(d => d.Date)
            .ToList();

        return new SalesReportDto
        {
            StartDate = startDate,
            EndDate = endDate,
            TotalRevenue = totalRevenue,
            TotalOrders = totalOrders,
            TotalTicketsSold = totalTicketsSold,
            SalesByInstitution = salesByInstitution,
            SalesByShow = salesByShow,
            DailySales = dailySales
        };
    }

    public async Task<PopularityReportDto> GetPopularityReportAsync(ReportFilterRequest filter)
    {
        var startDate = filter.StartDate ?? DateTime.UtcNow.AddMonths(-1);
        var endDate = filter.EndDate ?? DateTime.UtcNow;

        // Automatsko filtriranje po instituciji korisnika (ako ima ograničenje)
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        
        // Most Popular Shows
        var showsQuery = _dbContext.Shows
            .Include(s => s.Genre)
            .Include(s => s.Reviews)
            .Include(s => s.Performances)
                .ThenInclude(p => p.OrderItems)
                    .ThenInclude(oi => oi.Order)
            .Include(s => s.Performances)
                .ThenInclude(p => p.OrderItems)
                    .ThenInclude(oi => oi.Tickets)
            .AsQueryable();

        // Automatsko filtriranje po instituciji korisnika
        if (userInstitutionId.HasValue)
        {
            showsQuery = showsQuery.Where(s => s.InstitutionId == userInstitutionId.Value);
        }

        if (filter.InstitutionId.HasValue)
        {
            // Ako korisnik već ima ograničenje po instituciji, provjeriti da filter nije različit
            if (userInstitutionId.HasValue && filter.InstitutionId.Value != userInstitutionId.Value)
            {
                throw new UnauthorizedAccessException("Nemate pristup izvještajima za tu instituciju.");
            }
            showsQuery = showsQuery.Where(s => s.InstitutionId == filter.InstitutionId.Value);
        }

        if (filter.ShowId.HasValue)
        {
            showsQuery = showsQuery.Where(s => s.Id == filter.ShowId.Value);
        }

        var shows = await showsQuery.ToListAsync();

        var mostPopularShows = shows
            .Select(s => new
            {
                Show = s,
                TicketsSold = s.Performances
                    .SelectMany(p => p.OrderItems)
                    .Where(oi => oi.Order.Status == OrderStatus.Paid &&
                                oi.Order.CreatedAt >= startDate &&
                                oi.Order.CreatedAt <= endDate)
                    .SelectMany(oi => oi.Tickets)
                    .Count(t => t.Status == TicketStatus.NotScanned || t.Status == TicketStatus.Scanned),
                Revenue = s.Performances
                    .SelectMany(p => p.OrderItems)
                    .Where(oi => oi.Order.Status == OrderStatus.Paid &&
                                oi.Order.CreatedAt >= startDate &&
                                oi.Order.CreatedAt <= endDate)
                    .Sum(oi => oi.UnitPrice * oi.Quantity),
                ReviewsCount = s.Reviews.Count(r => r.CreatedAt >= startDate && r.CreatedAt <= endDate),
                AverageRating = s.Reviews.Any() ? s.Reviews.Average(r => r.Rating) : (double?)null
            })
            .Where(x => x.TicketsSold > 0)
            .OrderByDescending(x => x.TicketsSold)
            .Take(10)
            .Select(x => new ShowPopularityDto
            {
                ShowId = x.Show.Id,
                ShowTitle = x.Show.Title,
                TicketsSold = x.TicketsSold,
                ReviewsCount = x.ReviewsCount,
                AverageRating = x.AverageRating,
                Revenue = x.Revenue
            })
            .ToList();

        // Most Popular Genres
        var genresQuery = _dbContext.Genres
            .Include(g => g.Shows)
                .ThenInclude(s => s.Performances)
                    .ThenInclude(p => p.OrderItems)
                        .ThenInclude(oi => oi.Order)
            .Include(g => g.Shows)
                .ThenInclude(s => s.Performances)
                    .ThenInclude(p => p.OrderItems)
                    .ThenInclude(oi => oi.Tickets)
            .AsQueryable();

        // Filtrirati Shows po instituciji korisnika (ako ima ograničenje)
        // Ovo će filtrirati Shows unutar Genres
        var genres = await genresQuery.ToListAsync();
        
        // Ako korisnik ima ograničenje, filtrirati Shows unutar Genres
        if (userInstitutionId.HasValue)
        {
            foreach (var genre in genres)
            {
                genre.Shows = genre.Shows.Where(s => s.InstitutionId == userInstitutionId.Value).ToList();
            }
        }

        var mostPopularGenres = genres
            .Select(g => new
            {
                Genre = g,
                ShowsCount = g.Shows.Count,
                TicketsSold = g.Shows
                    .SelectMany(s => s.Performances)
                    .SelectMany(p => p.OrderItems)
                    .Where(oi => oi.Order.Status == OrderStatus.Paid &&
                                oi.Order.CreatedAt >= startDate &&
                                oi.Order.CreatedAt <= endDate)
                    .SelectMany(oi => oi.Tickets)
                    .Count(t => t.Status == TicketStatus.NotScanned || t.Status == TicketStatus.Scanned),
                Revenue = g.Shows
                    .SelectMany(s => s.Performances)
                    .SelectMany(p => p.OrderItems)
                    .Where(oi => oi.Order.Status == OrderStatus.Paid &&
                                oi.Order.CreatedAt >= startDate &&
                                oi.Order.CreatedAt <= endDate)
                    .Sum(oi => oi.UnitPrice * oi.Quantity)
            })
            .Where(x => x.TicketsSold > 0)
            .OrderByDescending(x => x.TicketsSold)
            .Take(10)
            .Select(x => new GenrePopularityDto
            {
                GenreId = x.Genre.Id,
                GenreName = x.Genre.Name,
                ShowsCount = x.ShowsCount,
                TicketsSold = x.TicketsSold,
                Revenue = x.Revenue
            })
            .ToList();

        // Most Popular Institutions
        var institutionsQuery = _dbContext.Institutions
            .Include(i => i.Shows)
                .ThenInclude(s => s.Performances)
                    .ThenInclude(p => p.OrderItems)
                        .ThenInclude(oi => oi.Order)
            .Include(i => i.Shows)
                .ThenInclude(s => s.Performances)
                    .ThenInclude(p => p.OrderItems)
                        .ThenInclude(oi => oi.Tickets)
            .AsQueryable();

        // Filtrirati institucije ako korisnik ima ograničenje
        if (userInstitutionId.HasValue)
        {
            institutionsQuery = institutionsQuery.Where(i => i.Id == userInstitutionId.Value);
        }

        var institutions = await institutionsQuery.ToListAsync();

        var mostPopularInstitutions = institutions
            .Select(i => new
            {
                Institution = i,
                ShowsCount = i.Shows.Count,
                TicketsSold = i.Shows
                    .SelectMany(s => s.Performances)
                    .SelectMany(p => p.OrderItems)
                    .Where(oi => oi.Order.Status == OrderStatus.Paid &&
                                oi.Order.CreatedAt >= startDate &&
                                oi.Order.CreatedAt <= endDate)
                    .SelectMany(oi => oi.Tickets)
                    .Count(t => t.Status == TicketStatus.NotScanned || t.Status == TicketStatus.Scanned),
                Revenue = i.Shows
                    .SelectMany(s => s.Performances)
                    .SelectMany(p => p.OrderItems)
                    .Where(oi => oi.Order.Status == OrderStatus.Paid &&
                                oi.Order.CreatedAt >= startDate &&
                                oi.Order.CreatedAt <= endDate)
                    .Sum(oi => oi.UnitPrice * oi.Quantity)
            })
            .Where(x => x.TicketsSold > 0)
            .OrderByDescending(x => x.TicketsSold)
            .Take(10)
            .Select(x => new InstitutionPopularityDto
            {
                InstitutionId = x.Institution.Id,
                InstitutionName = x.Institution.Name,
                ShowsCount = x.ShowsCount,
                TicketsSold = x.TicketsSold,
                Revenue = x.Revenue
            })
            .ToList();

        return new PopularityReportDto
        {
            StartDate = startDate,
            EndDate = endDate,
            MostPopularShows = mostPopularShows,
            MostPopularGenres = mostPopularGenres,
            MostPopularInstitutions = mostPopularInstitutions
        };
    }
}

