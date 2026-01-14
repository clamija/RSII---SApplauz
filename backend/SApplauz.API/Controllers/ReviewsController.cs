using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReviewsController : ControllerBase
{
    private readonly IReviewService _reviewService;
    private readonly ICurrentUserService _currentUserService;
    private readonly ILogger<ReviewsController> _logger;

    public ReviewsController(
        IReviewService reviewService,
        ICurrentUserService currentUserService,
        ILogger<ReviewsController> logger)
    {
        _reviewService = reviewService;
        _currentUserService = currentUserService;
        _logger = logger;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<List<ReviewDto>>> GetReviews([FromQuery] ReviewFilterRequest filter)
    {
        try
        {
            if (filter.PageNumber < 1) filter.PageNumber = 1;
            if (filter.PageSize < 1 || filter.PageSize > 100) filter.PageSize = 10;
            // Public endpoint: vrati samo vidljive recenzije
            filter.IsVisible ??= true;

            var reviews = await _reviewService.GetReviewsAsync(filter);
            return Ok(reviews);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting reviews");
            return StatusCode(500, new { message = "Greška pri dohvatanju recenzija." });
        }
    }

    [HttpGet("management")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<List<ReviewDto>>> GetReviewsForManagement([FromQuery] ReviewFilterRequest filter)
    {
        try
        {
            if (filter.PageNumber < 1) filter.PageNumber = 1;
            if (filter.PageSize < 1 || filter.PageSize > 100) filter.PageSize = 10;

            var reviews = await _reviewService.GetReviewsForManagementAsync(filter);
            return Ok(reviews);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting reviews for management");
            return StatusCode(500, new { message = "Greška pri dohvatanju recenzija." });
        }
    }

    [HttpGet("{id}")]
    [AllowAnonymous]
    public async Task<ActionResult<ReviewDto>> GetReview(int id)
    {
        try
        {
            var review = await _reviewService.GetReviewByIdAsync(id);
            if (review == null)
            {
                return NotFound(new { message = $"Recenzija sa ID {id} nije pronađena." });
            }
            return Ok(review);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting review {ReviewId}", id);
            return StatusCode(500, new { message = "Greška pri dohvatanju recenzije." });
        }
    }

    [HttpGet("can-review")]
    [Authorize]
    public async Task<ActionResult<object>> CanReview([FromQuery] int showId)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Ok(new { canReview = false, message = "Korisnik nije autentifikovan." });
            }

            var validation = await _reviewService.ValidateReviewEligibilityAsync(_currentUserService.UserId, showId);
            var canReview = validation.IsValid;
            return Ok(new
            {
                canReview,
                message = canReview
                    ? "Možete ostaviti recenziju."
                    : validation.Message
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking can-review for show {ShowId}", showId);
            return StatusCode(500, new { canReview = false, message = "Greška pri provjeri mogućnosti recenziranja." });
        }
    }

    [HttpPost]
    [Authorize]
    public async Task<ActionResult<ReviewDto>> CreateReview([FromBody] CreateReviewRequest request)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            // Validate review eligibility (validation is done inside CreateReviewAsync now)
            var review = await _reviewService.CreateReviewAsync(_currentUserService.UserId, request);
            
            // Check if review was updated (not created) by checking if UpdatedAt is very recent
            // If UpdatedAt exists and is within last minute, it was just updated
            if (review.UpdatedAt.HasValue && review.CreatedAt < review.UpdatedAt.Value)
            {
                // Review was just updated (not created), return 200 OK
                return Ok(new { 
                    data = review, 
                    message = "Recenzija je uspješno ažurirana." 
                });
            }
            
            return CreatedAtAction(nameof(GetReview), new { id = review.Id }, new { 
                data = review, 
                message = "Recenzija je uspješno kreirana." 
            });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            // This will catch validation errors from ValidateReviewEligibilityAsync
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating review");
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id}")]
    [Authorize]
    public async Task<ActionResult<ReviewDto>> UpdateReview(int id, [FromBody] UpdateReviewRequest request)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            var review = await _reviewService.UpdateReviewAsync(id, _currentUserService.UserId, request);
            return Ok(review);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating review {ReviewId}", id);
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    [Authorize]
    public async Task<IActionResult> DeleteReview(int id)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            // Allow deletion if user owns review or is admin
            var isAdmin = _currentUserService.Roles.Any(role => 
                role == ApplicationRoles.SuperAdmin || ApplicationRoles.IsAdminRole(role));

            if (!isAdmin)
            {
                await _reviewService.DeleteReviewAsync(id, _currentUserService.UserId);
            }
            else
            {
                // Admin can delete any review - we'll need to add a method for this
                // For now, we'll use the existing method which checks ownership
                // TODO: Add DeleteReviewAsync(int id) without userId check for admins
                await _reviewService.DeleteReviewAsync(id, _currentUserService.UserId);
            }

            return NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting review {ReviewId}", id);
            return StatusCode(500, new { message = "Greška pri brisanju recenzije." });
        }
    }

    [HttpPut("{id}/visibility")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<ReviewDto>> UpdateReviewVisibility(int id, [FromBody] bool isVisible)
    {
        try
        {
            var review = await _reviewService.UpdateReviewVisibilityAsync(id, isVisible);
            return Ok(review);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating review visibility {ReviewId}", id);
            return StatusCode(500, new { message = "Greška pri ažuriranju vidljivosti recenzije." });
        }
    }
}





