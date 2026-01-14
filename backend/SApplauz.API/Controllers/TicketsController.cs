using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TicketsController : ControllerBase
{
    private readonly ITicketService _ticketService;
    private readonly ICurrentUserService _currentUserService;
    private readonly ILogger<TicketsController> _logger;

    public TicketsController(
        ITicketService ticketService,
        ICurrentUserService currentUserService,
        ILogger<TicketsController> logger)
    {
        _ticketService = ticketService;
        _currentUserService = currentUserService;
        _logger = logger;
    }

    [HttpGet("my-tickets")]
    public async Task<ActionResult<List<TicketDto>>> GetMyTickets()
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            var tickets = await _ticketService.GetUserTicketsAsync(_currentUserService.UserId);
            return Ok(tickets);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting user tickets");
            return StatusCode(500, new { message = "Greška pri dohvatanju karata." });
        }
    }

    [HttpGet("qr/{qrCode}")]
    [AllowAnonymous]
    public async Task<ActionResult<TicketDto>> GetTicketByQRCode(string qrCode)
    {
        try
        {
            var ticket = await _ticketService.GetTicketByQRCodeAsync(qrCode);
            if (ticket == null)
            {
                return NotFound(new { message = "Karta sa datim QR kodom nije pronađena." });
            }
            return Ok(ticket);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting ticket by QR code");
            return StatusCode(500, new { message = "Greška pri dohvatanju karte." });
        }
    }

    [HttpPost("validate")]
    [Authorize(Roles = ApplicationRoles.AllBlagajnikRoles)]
    public async Task<ActionResult<ValidateTicketResponse>> ValidateTicket([FromBody] ValidateTicketRequest request)
    {
        try
        {
            // SuperAdmin može validirati karte svih institucija (bez InstitutionId ograničenja)
            if (User.IsInRole(ApplicationRoles.SuperAdmin) ||
                _currentUserService.Roles.Contains(ApplicationRoles.SuperAdmin, StringComparer.OrdinalIgnoreCase))
            {
                var superAdminResponse = await _ticketService.ValidateTicketAsync(request.QRCode, institutionId: null);
                return superAdminResponse.IsValid ? Ok(superAdminResponse) : BadRequest(superAdminResponse);
            }

            // Admin/Blagajnik moraju imati InstitutionId (validacija samo za svoju instituciju)
            var institutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
            if (!institutionId.HasValue)
            {
                return Unauthorized(new { message = "Nemate pristup validaciji karata. Potrebna je uloga Blagajnik za određenu instituciju." });
            }

            var response = await _ticketService.ValidateTicketAsync(request.QRCode, institutionId);
            
            if (response.IsValid)
            {
                return Ok(response);
            }
            else
            {
                return BadRequest(response);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error validating ticket");
            return StatusCode(500, new { message = "Greška pri validaciji karte." });
        }
    }

    // Pregled plaćenih karata (SuperAdmin: sve institucije ili filtrirano; Admin/Blagajnik: samo svoja institucija)
    [HttpGet("scanned")]
    [Authorize(Roles = ApplicationRoles.AllAdminAndBlagajnikRoles)]
    public async Task<ActionResult<List<TicketDto>>> GetPaidTickets(
        [FromQuery] int? institutionId = null,
        [FromQuery] string? status = null)
    {
        try
        {
            // Ako korisnik ima institucijsko ograničenje (Admin/Blagajnik), forsiraj tu instituciju
            var userInstitutionId = await _currentUserService.GetInstitutionIdForCurrentUserAsync();
            if (userInstitutionId.HasValue)
            {
                institutionId = userInstitutionId.Value;
            }

            var tickets = await _ticketService.GetPaidTicketsAsync(institutionId, status);
            return Ok(tickets);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting paid tickets");
            return StatusCode(500, new { message = "Greška pri dohvatanju karata." });
        }
    }
}





