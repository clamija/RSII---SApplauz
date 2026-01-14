using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface IReviewService
{
    Task<ReviewDto?> GetReviewByIdAsync(int id);
    Task<List<ReviewDto>> GetReviewsAsync(ReviewFilterRequest filter);
    Task<List<ReviewDto>> GetReviewsForManagementAsync(ReviewFilterRequest filter);
    Task<ReviewDto> CreateReviewAsync(string userId, CreateReviewRequest request);
    Task<ReviewDto> UpdateReviewAsync(int id, string userId, UpdateReviewRequest request);
    Task DeleteReviewAsync(int id, string userId);
    Task<ReviewDto> UpdateReviewVisibilityAsync(int id, bool isVisible);
    Task<bool> CanUserReviewShowAsync(string userId, int showId);
    Task<ReviewEligibilityDto> ValidateReviewEligibilityAsync(string userId, int showId);
}






