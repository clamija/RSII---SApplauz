using AutoMapper;
using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Services;

public class ReviewService : IReviewService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IMapper _mapper;
    private readonly ICurrentUserService _currentUserService;
    private readonly IRecommendationService? _recommendationService;

    public ReviewService(
        ApplicationDbContext dbContext, 
        IMapper mapper,
        ICurrentUserService currentUserService,
        IRecommendationService? recommendationService = null)
    {
        _dbContext = dbContext;
        _mapper = mapper;
        _currentUserService = currentUserService;
        _recommendationService = recommendationService;
    }

    public async Task<ReviewDto?> GetReviewByIdAsync(int id)
    {
        var query = _dbContext.Reviews
            .Include(r => r.Show)
                .ThenInclude(s => s.Institution)
            .AsQueryable();

        var review = await query.FirstOrDefaultAsync(r => r.Id == id);

        if (review == null)
        {
            return null;
        }

        var dto = _mapper.Map<ReviewDto>(review);
        dto.ShowTitle = review.Show.Title;
        
        // Get user name from ApplicationUser
        var user = await _dbContext.Users.FindAsync(review.UserId);
        dto.UserName = user != null ? $"{user.FirstName} {user.LastName}" : "Nepoznat korisnik";
        
        return dto;
    }

    public async Task<List<ReviewDto>> GetReviewsAsync(ReviewFilterRequest filter)
    {
        var query = _dbContext.Reviews
            .Include(r => r.Show)
                .ThenInclude(s => s.Institution)
            .AsQueryable();

        // Apply filters
        if (filter.ShowId.HasValue)
        {
            query = query.Where(r => r.ShowId == filter.ShowId.Value);
        }

        if (!string.IsNullOrWhiteSpace(filter.UserId))
        {
            query = query.Where(r => r.UserId == filter.UserId);
        }

        // Public pregled: ako nije eksplicitno traženo, vrati samo vidljive recenzije
        if (filter.IsVisible.HasValue)
            query = query.Where(r => r.IsVisible == filter.IsVisible.Value);
        else
            query = query.Where(r => r.IsVisible);

        if (filter.MinRating.HasValue)
        {
            query = query.Where(r => r.Rating >= filter.MinRating.Value);
        }

        var reviews = await query
            .OrderByDescending(r => r.CreatedAt)
            .Skip((filter.PageNumber - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .ToListAsync();

        // Get user names
        var userIds = reviews.Select(r => r.UserId).Distinct().ToList();
        var users = await _dbContext.Users
            .Where(u => userIds.Contains(u.Id))
            .ToListAsync();

        return reviews.Select(review =>
        {
            var dto = _mapper.Map<ReviewDto>(review);
            dto.ShowTitle = review.Show.Title;
            var user = users.FirstOrDefault(u => u.Id == review.UserId);
            dto.UserName = user != null ? $"{user.FirstName} {user.LastName}" : "Nepoznat korisnik";
            return dto;
        }).ToList();
    }

    public async Task<List<ReviewDto>> GetReviewsForManagementAsync(ReviewFilterRequest filter)
    {
        var query = _dbContext.Reviews
            .Include(r => r.Show)
                .ThenInclude(s => s.Institution)
            .AsQueryable();

        // Management pregled: ograniči po instituciji ako korisnik ima scope (SuperAdmin nema)
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query.Where(r => r.Show.InstitutionId == userInstitutionId.Value);
        }

        if (filter.ShowId.HasValue)
        {
            query = query.Where(r => r.ShowId == filter.ShowId.Value);
        }

        if (!string.IsNullOrWhiteSpace(filter.UserId))
        {
            query = query.Where(r => r.UserId == filter.UserId);
        }

        // Management: IsVisible filter je opcionalan (može vidjeti i skrivene)
        if (filter.IsVisible.HasValue)
        {
            query = query.Where(r => r.IsVisible == filter.IsVisible.Value);
        }

        if (filter.MinRating.HasValue)
        {
            query = query.Where(r => r.Rating >= filter.MinRating.Value);
        }

        var reviews = await query
            .OrderByDescending(r => r.CreatedAt)
            .Skip((filter.PageNumber - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .ToListAsync();

        var userIds = reviews.Select(r => r.UserId).Distinct().ToList();
        var users = await _dbContext.Users
            .Where(u => userIds.Contains(u.Id))
            .ToListAsync();

        return reviews.Select(review =>
        {
            var dto = _mapper.Map<ReviewDto>(review);
            dto.ShowTitle = review.Show.Title;
            var user = users.FirstOrDefault(u => u.Id == review.UserId);
            dto.UserName = user != null ? $"{user.FirstName} {user.LastName}" : "Nepoznat korisnik";
            return dto;
        }).ToList();
    }

    public async Task<ReviewDto> CreateReviewAsync(string userId, CreateReviewRequest request)
    {
        // Verify show exists
        var show = await _dbContext.Shows.FindAsync(request.ShowId);
        if (show == null)
        {
            throw new KeyNotFoundException($"Show with id {request.ShowId} not found.");
        }

        // Validate review eligibility (scanned ticket + ended performance)
        var validation = await ValidateReviewEligibilityAsync(userId, request.ShowId);
        if (!validation.IsValid)
        {
            throw new InvalidOperationException(validation.Message);
        }

        // Check if user already reviewed this show - if yes, update instead of creating new
        var existingReview = await _dbContext.Reviews
            .FirstOrDefaultAsync(r => r.UserId == userId && r.ShowId == request.ShowId);

        if (existingReview != null)
        {
            // Update existing review instead of creating new one
            existingReview.Rating = request.Rating;
            existingReview.Comment = request.Comment;
            existingReview.UpdatedAt = DateTime.UtcNow;
            
            await _dbContext.SaveChangesAsync();

            // Ažuriraj recommendation profile
            if (_recommendationService != null)
            {
                try
                {
                    await _recommendationService.UpdateUserPreferencesAsync(userId, request.ShowId, request.Rating);
                    await _recommendationService.InvalidateUserCacheAsync(userId);
                }
                catch
                {
                    // Ignoriraj greške u recommendation servisu - ne treba da blokira ažuriranje recenzije
                }
            }

            return await GetReviewByIdAsync(existingReview.Id) ?? throw new InvalidOperationException("Failed to retrieve updated review.");
        }

        // Create new review
        var review = new Review
        {
            UserId = userId,
            ShowId = request.ShowId,
            Rating = request.Rating,
            Comment = request.Comment,
            IsVisible = true,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.Reviews.Add(review);
        await _dbContext.SaveChangesAsync();

        // Ažuriraj recommendation profile
        if (_recommendationService != null)
        {
            try
            {
                await _recommendationService.UpdateUserPreferencesAsync(userId, request.ShowId, request.Rating);
                await _recommendationService.InvalidateUserCacheAsync(userId);
            }
            catch
            {
                // Ignoriraj greške u recommendation servisu - ne treba da blokira kreiranje recenzije
            }
        }

        return await GetReviewByIdAsync(review.Id) ?? throw new InvalidOperationException("Failed to retrieve created review.");
    }

    public async Task<ReviewDto> UpdateReviewAsync(int id, string userId, UpdateReviewRequest request)
    {
        var review = await _dbContext.Reviews.FindAsync(id);
        if (review == null)
        {
            throw new KeyNotFoundException($"Review with id {id} not found.");
        }

        // Check if user owns this review
        if (review.UserId != userId)
        {
            throw new UnauthorizedAccessException($"User does not have permission to update review {id}.");
        }

        review.Rating = request.Rating;
        review.Comment = request.Comment;

        await _dbContext.SaveChangesAsync();

        return await GetReviewByIdAsync(review.Id) ?? throw new InvalidOperationException("Failed to retrieve updated review.");
    }

    public async Task DeleteReviewAsync(int id, string userId)
    {
        var review = await _dbContext.Reviews.FindAsync(id);
        if (review == null)
        {
            throw new KeyNotFoundException($"Review with id {id} not found.");
        }

        // Check if user owns this review (or is admin - this will be checked in controller)
        if (review.UserId != userId)
        {
            throw new UnauthorizedAccessException($"User does not have permission to delete review {id}.");
        }

        _dbContext.Reviews.Remove(review);
        await _dbContext.SaveChangesAsync();
    }

    public async Task<ReviewDto> UpdateReviewVisibilityAsync(int id, bool isVisible)
    {
        var query = _dbContext.Reviews
            .Include(r => r.Show)
                .ThenInclude(s => s.Institution)
            .AsQueryable();
        
        // Filtriranje po instituciji ako korisnik ima ograničenje
        var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
        if (userInstitutionId.HasValue)
        {
            query = query.Where(r => r.Show.InstitutionId == userInstitutionId.Value);
        }

        var review = await query.FirstOrDefaultAsync(r => r.Id == id);
        if (review == null)
        {
            throw new KeyNotFoundException($"Review with id {id} not found.");
        }

        review.IsVisible = isVisible;
        await _dbContext.SaveChangesAsync();

        return await GetReviewByIdAsync(review.Id) ?? throw new InvalidOperationException("Failed to retrieve updated review.");
    }

    public async Task<bool> CanUserReviewShowAsync(string userId, int showId)
    {
        // Koristi istu validaciju kao i CreateReviewAsync (da UI i backend budu 100% usklađeni)
        var validation = await ValidateReviewEligibilityAsync(userId, showId);
        return validation.IsValid;
    }

    public async Task<ReviewEligibilityDto> ValidateReviewEligibilityAsync(string userId, int showId)
    {
        var now = GetNowInAppTimeZone();
        
        // Check if user has PAID + scanned ticket for this show
        var tickets = await _dbContext.Tickets
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Order)
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
            .Where(t => t.OrderItem.Order.UserId == userId &&
                       t.OrderItem.Performance.ShowId == showId &&
                       t.OrderItem.Order.Status == Domain.Entities.OrderStatus.Paid &&
                       t.Status == Domain.Entities.TicketStatus.Scanned)
            .ToListAsync();

        if (!tickets.Any())
        {
            return new ReviewEligibilityDto
            {
                IsValid = false,
                Message = "Možete ostaviti recenziju samo nakon što kupite kartu i odgledate predstavu."
            };
        }

        // Check if any performance has ended (StartTime + DurationMinutes < now)
        var hasEndedPerformance = tickets.Any(t =>
        {
            var duration = t.OrderItem.Performance.Show.DurationMinutes > 0 ? t.OrderItem.Performance.Show.DurationMinutes : 90;
            return t.OrderItem.Performance.StartTime.AddMinutes(duration) < now;
        });
        
        if (!hasEndedPerformance)
        {
            return new ReviewEligibilityDto
            {
                IsValid = false,
                Message = "Možete ostaviti recenziju samo nakon što odgledate predstavu. Termin još nije završio."
            };
        }

        return new ReviewEligibilityDto
        {
            IsValid = true,
            Message = string.Empty
        };
    }

    private static DateTime GetNowInAppTimeZone()
    {
        // Performance/Show vremena se tretiraju kao lokalno vrijeme; koristimo isti pristup kao kod validacije karata.
        var tz = GetAppTimeZone();
        return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
    }

    private static TimeZoneInfo GetAppTimeZone()
    {
        try { return TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo"); } catch { /* ignore */ }
        try { return TimeZoneInfo.FindSystemTimeZoneById("Central European Standard Time"); } catch { /* ignore */ }
        return TimeZoneInfo.Local;
    }
}

