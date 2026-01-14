using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ShowsController : ControllerBase
{
    private readonly IShowService _showService;
    private readonly ILogger<ShowsController> _logger;

    public ShowsController(
        IShowService showService,
        ILogger<ShowsController> logger)
    {
        _showService = showService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<ShowListResponse>> GetShows([FromQuery] ShowFilterRequest filter)
    {
        try
        {
            if (filter.PageNumber < 1) filter.PageNumber = 1;
            if (filter.PageSize < 1 || filter.PageSize > 100) filter.PageSize = 10;

            var response = await _showService.GetShowsPublicAsync(filter);
            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting shows");
            return StatusCode(500, new { message = "Greška pri dohvatanju predstava." });
        }
    }

    [HttpGet("management")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<ShowListResponse>> GetShowsForManagement([FromQuery] ShowFilterRequest filter)
    {
        try
        {
            if (filter.PageNumber < 1) filter.PageNumber = 1;
            if (filter.PageSize < 1 || filter.PageSize > 100) filter.PageSize = 10;

            var response = await _showService.GetShowsAsync(filter);
            return Ok(response);
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(403, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting shows for management");
            return StatusCode(500, new { message = "Greška pri dohvatanju predstava." });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ShowDto>> GetShow(int id)
    {
        try
        {
            var show = await _showService.GetShowByIdAsync(id);
            if (show == null)
            {
                return NotFound(new { message = $"Predstava sa ID {id} nije pronađena." });
            }
            return Ok(show);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting show {ShowId}", id);
            return StatusCode(500, new { message = "Greška pri dohvatanju predstave." });
        }
    }

    [HttpPost]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<ShowDto>> CreateShow([FromBody] CreateShowRequest request)
    {
        try
        {
            var show = await _showService.CreateShowAsync(request);
            return CreatedAtAction(nameof(GetShow), new { id = show.Id }, new { 
                data = show, 
                message = "Predstava je uspješno kreirana." 
            });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(403, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating show");
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id}")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<ShowDto>> UpdateShow(int id, [FromBody] UpdateShowRequest request)
    {
        try
        {
            var show = await _showService.UpdateShowAsync(id, request);
            return Ok(new { 
                data = show, 
                message = "Predstava je uspješno ažurirana." 
            });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(403, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating show {ShowId}", id);
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<IActionResult> DeleteShow(int id)
    {
        try
        {
            await _showService.DeleteShowAsync(id);
            return NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(403, new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting show {ShowId}", id);
            return StatusCode(500, new { message = "Greška pri brisanju predstave." });
        }
    }
}





