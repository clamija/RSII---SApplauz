using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PerformancesController : ControllerBase
{
    private readonly IPerformanceService _performanceService;
    private readonly ILogger<PerformancesController> _logger;

    public PerformancesController(
        IPerformanceService performanceService,
        ILogger<PerformancesController> logger)
    {
        _performanceService = performanceService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<List<PerformanceDto>>> GetPerformances([FromQuery] PerformanceFilterRequest filter)
    {
        try
        {
            if (filter.PageNumber < 1) filter.PageNumber = 1;
            if (filter.PageSize < 1 || filter.PageSize > 100) filter.PageSize = 10;

            var performances = await _performanceService.GetPerformancesAsync(filter);
            return Ok(performances);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting performances");
            return StatusCode(500, new { message = "Greška pri dohvatanju termina." });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<PerformanceDto>> GetPerformance(int id)
    {
        try
        {
            var performance = await _performanceService.GetPerformanceByIdAsync(id);
            if (performance == null)
            {
                return NotFound(new { message = $"Termin sa ID {id} nije pronađen." });
            }
            return Ok(performance);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting performance {PerformanceId}", id);
            return StatusCode(500, new { message = "Greška pri dohvatanju termina." });
        }
    }

    [HttpPost]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<PerformanceDto>> CreatePerformance([FromBody] CreatePerformanceRequest request)
    {
        try
        {
            var performance = await _performanceService.CreatePerformanceAsync(request);
            return CreatedAtAction(nameof(GetPerformance), new { id = performance.Id }, new { 
                data = performance, 
                message = "Termin je uspješno kreiran." 
            });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating performance");
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id}")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<PerformanceDto>> UpdatePerformance(int id, [FromBody] UpdatePerformanceRequest request)
    {
        try
        {
            var performance = await _performanceService.UpdatePerformanceAsync(id, request);
            return Ok(new { 
                data = performance, 
                message = "Termin je uspješno ažuriran." 
            });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating performance {PerformanceId}", id);
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<IActionResult> DeletePerformance(int id)
    {
        try
        {
            await _performanceService.DeletePerformanceAsync(id);
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
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting performance {PerformanceId}", id);
            return StatusCode(500, new { message = "Greška pri brisanju termina." });
        }
    }

    [HttpGet("{id}/availability")]
    public async Task<ActionResult<bool>> CheckAvailability(int id, [FromQuery] int quantity = 1)
    {
        try
        {
            var isAvailable = await _performanceService.CheckAvailabilityAsync(id, quantity);
            return Ok(new { isAvailable, quantity });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking availability for performance {PerformanceId}", id);
            return StatusCode(500, new { message = "Greška pri provjeri dostupnosti." });
        }
    }
}





