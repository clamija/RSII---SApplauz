using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

/// <summary>
/// Controller za upravljanje preporukama predstava.
/// Omogućava korisnicima da dobiju personalizovane preporuke na osnovu njihove historije.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RecommendationsController : ControllerBase
{
    private readonly IRecommendationService _recommendationService;
    private readonly ICurrentUserService _currentUserService;
    private readonly ILogger<RecommendationsController> _logger;

    /// <summary>
    /// Inicijalizuje novu instancu RecommendationsController.
    /// </summary>
    /// <param name="recommendationService">Servis za generisanje preporuka</param>
    /// <param name="currentUserService">Servis za pristup trenutnom korisniku</param>
    /// <param name="logger">Logger za logovanje operacija</param>
    public RecommendationsController(
        IRecommendationService recommendationService,
        ICurrentUserService currentUserService,
        ILogger<RecommendationsController> logger)
    {
        _recommendationService = recommendationService;
        _currentUserService = currentUserService;
        _logger = logger;
    }

    /// <summary>
    /// Vraća personalizovane preporuke predstava za trenutnog korisnika.
    /// Ako korisnik nema historiju, vraća popularne predstave (cold start).
    /// </summary>
    /// <param name="count">Broj preporuka koje treba vratiti (default: 10, min: 1, max: 50)</param>
    /// <returns>Lista preporuka sa score-om i razlogom</returns>
    /// <response code="200">Uspješno vraćene preporuke</response>
    /// <response code="400">Nevalidan count parametar</response>
    /// <response code="401">Korisnik nije autentifikovan</response>
    /// <response code="500">Greška pri generisanju preporuka</response>
    [HttpGet]
    [Authorize(Roles = ApplicationRoles.Korisnik)]
    public async Task<ActionResult<RecommendationListResponse>> GetRecommendations([FromQuery] int count = 10)
    {
        try
        {
            var userId = _currentUserService.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
            
            if (count < 1 || count > 50)
            {
                return BadRequest(new { message = "Count must be between 1 and 50." });
            }

            var recommendations = await _recommendationService.GetRecommendationsAsync(userId, count);
            
            return Ok(new RecommendationListResponse
            {
                Recommendations = recommendations,
                TotalCount = recommendations.Count
            });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting recommendations");
            return StatusCode(500, new { message = "An error occurred while retrieving recommendations." });
        }
    }
}





