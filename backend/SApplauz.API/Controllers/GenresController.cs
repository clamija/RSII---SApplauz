using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class GenresController : ControllerBase
{
    private readonly IGenreService _genreService;
    private readonly ILogger<GenresController> _logger;

    public GenresController(
        IGenreService genreService,
        ILogger<GenresController> logger)
    {
        _genreService = genreService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<List<GenreDto>>> GetGenres()
    {
        try
        {
            var genres = await _genreService.GetAllGenresAsync();
            return Ok(genres);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting genres");
            return StatusCode(500, new { message = "Greška pri dohvatanju žanrova." });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<GenreDto>> GetGenre(int id)
    {
        try
        {
            var genre = await _genreService.GetGenreByIdAsync(id);
            if (genre == null)
            {
                return NotFound(new { message = $"Žanr sa ID {id} nije pronađen." });
            }
            return Ok(genre);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting genre {GenreId}", id);
            return StatusCode(500, new { message = "Greška pri dohvatanju žanra." });
        }
    }

    [HttpPost]
    [Authorize(Roles = ApplicationRoles.SuperAdmin)]
    public async Task<ActionResult<GenreDto>> CreateGenre([FromBody] CreateGenreRequest request)
    {
        try
        {
            var genre = await _genreService.CreateGenreAsync(request);
            return CreatedAtAction(nameof(GetGenre), new { id = genre.Id }, new { 
                data = genre, 
                message = "Žanr je uspješno kreiran." 
            });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating genre");
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPut("{id}")]
    [Authorize(Roles = ApplicationRoles.SuperAdmin)]
    public async Task<ActionResult<GenreDto>> UpdateGenre(int id, [FromBody] UpdateGenreRequest request)
    {
        try
        {
            var genre = await _genreService.UpdateGenreAsync(id, request);
            return Ok(new { 
                data = genre, 
                message = "Žanr je uspješno ažuriran." 
            });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating genre {GenreId}", id);
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = ApplicationRoles.SuperAdmin)]
    public async Task<IActionResult> DeleteGenre(int id)
    {
        try
        {
            await _genreService.DeleteGenreAsync(id);
            return Ok(new { message = "Žanr je uspješno obrisan." });
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
            _logger.LogError(ex, "Error deleting genre {GenreId}", id);
            return StatusCode(500, new { message = "Greška pri brisanju žanra." });
        }
    }
}






