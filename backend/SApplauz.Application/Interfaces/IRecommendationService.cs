using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface IRecommendationService
{
    Task<List<RecommendationDto>> GetRecommendationsAsync(string userId, int count = 10);
    Task UpdateUserPreferencesAsync(string userId, int showId, int? rating = null);
    Task InvalidateUserCacheAsync(string userId);
}






