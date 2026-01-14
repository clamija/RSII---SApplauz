using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class InstitutionsController : ControllerBase
{
    private readonly IInstitutionService _institutionService;
    private readonly ILogger<InstitutionsController> _logger;

    public InstitutionsController(
        IInstitutionService institutionService,
        ILogger<InstitutionsController> logger)
    {
        _institutionService = institutionService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<List<InstitutionDto>>> GetInstitutions([FromQuery] bool? isActive = null)
    {
        try
        {
            var institutions = await _institutionService.GetAllInstitutionsAsync(isActive);
            return Ok(institutions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting institutions");
            return StatusCode(500, new { message = "Greška pri dohvatanju institucija." });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<InstitutionDto>> GetInstitution(int id)
    {
        try
        {
            var institution = await _institutionService.GetInstitutionByIdAsync(id);
            if (institution == null)
            {
                return NotFound(new { message = $"Institucija sa ID {id} nije pronađena." });
            }
            return Ok(institution);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting institution {InstitutionId}", id);
            return StatusCode(500, new { message = "Greška pri dohvatanju institucije." });
        }
    }

    [HttpPost]
    [Authorize(Roles = ApplicationRoles.SuperAdmin)]
    public async Task<ActionResult<InstitutionDto>> CreateInstitution([FromBody] CreateInstitutionRequest request)
    {
        try
        {
            var institution = await _institutionService.CreateInstitutionAsync(request);
            return CreatedAtAction(nameof(GetInstitution), new { id = institution.Id }, new { 
                data = institution, 
                message = "Institucija je uspješno kreirana." 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating institution");
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id}")]
    [Authorize(Roles = ApplicationRoles.SuperAdmin)]
    public async Task<ActionResult<InstitutionDto>> UpdateInstitution(int id, [FromBody] UpdateInstitutionRequest request)
    {
        try
        {
            var institution = await _institutionService.UpdateInstitutionAsync(id, request);
            return Ok(new { 
                data = institution, 
                message = "Institucija je uspješno ažurirana." 
            });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating institution {InstitutionId}", id);
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = ApplicationRoles.SuperAdmin)]
    public async Task<IActionResult> DeleteInstitution(int id)
    {
        try
        {
            await _institutionService.DeleteInstitutionAsync(id);
            return Ok(new { message = "Institucija je uspješno obrisana." });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting institution {InstitutionId}", id);
            return StatusCode(500, new { message = "Greška pri brisanju institucije." });
        }
    }
}






