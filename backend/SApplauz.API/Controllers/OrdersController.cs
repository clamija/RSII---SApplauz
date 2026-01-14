using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly ICurrentUserService _currentUserService;
    private readonly ILogger<OrdersController> _logger;

    public OrdersController(
        IOrderService orderService,
        ICurrentUserService currentUserService,
        ILogger<OrdersController> logger)
    {
        _orderService = orderService;
        _currentUserService = currentUserService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<OrderListResponse>> GetMyOrders(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] int? institutionId = null,
        [FromQuery] string? status = null,
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            if (pageNumber < 1) pageNumber = 1;
            if (pageSize < 1 || pageSize > 100) pageSize = 10;

            // Ako je korisnik Admin/Blagajnik/SuperAdmin, ovaj endpoint služi i za pregled "transakcija" (narudžbi) po instituciji.
            // - SuperAdmin: može vidjeti sve (institutionId optional)
            // - Admin/Blagajnik: vidi samo svoju instituciju (ignoriši institutionId)
            // - Korisnik: vidi samo svoje narudžbe (ignoriši admin filtere)
            var isSuperAdmin = _currentUserService.Roles.Contains(Domain.Constants.ApplicationRoles.SuperAdmin, StringComparer.OrdinalIgnoreCase);
            var isInstitutionStaff = _currentUserService.Roles.Any(r =>
                Domain.Constants.ApplicationRoles.IsAdminRole(r) || Domain.Constants.ApplicationRoles.IsBlagajnikRole(r));

            OrderListResponse response;
            if (isSuperAdmin || isInstitutionStaff)
            {
                var enforcedInstitutionId = isSuperAdmin ? institutionId : await _currentUserService.GetInstitutionIdForCurrentUserAsync();
                response = await _orderService.GetInstitutionOrdersAsync(enforcedInstitutionId, pageNumber, pageSize, status, startDate, endDate);
            }
            else
            {
                response = await _orderService.GetUserOrdersAsync(_currentUserService.UserId, pageNumber, pageSize);
            }
            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting user orders");
            return StatusCode(500, new { message = "Greška pri dohvatanju narudžbi." });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<OrderDto>> GetOrder(int id)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            var order = await _orderService.GetOrderByIdAsync(id);
            if (order == null)
            {
                return NotFound(new { message = $"Narudžba sa ID {id} nije pronađena." });
            }

            // Check if user owns this order
            if (order.UserId != _currentUserService.UserId)
            {
                return Forbid("Nemate pristup ovoj narudžbi.");
            }

            return Ok(order);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting order {OrderId}", id);
            return StatusCode(500, new { message = "Greška pri dohvatanju narudžbe." });
        }
    }

    [HttpPost]
    public async Task<ActionResult<OrderDto>> CreateOrder([FromBody] CreateOrderRequest request)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            var order = await _orderService.CreateOrderAsync(_currentUserService.UserId, request);
            return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, new { 
                data = order, 
                message = "Narudžba je uspješno kreirana." 
            });
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
            _logger.LogError(ex, "Error creating order");
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPost("{id}/cancel")]
    public async Task<ActionResult<OrderDto>> CancelOrder(int id)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            var order = await _orderService.CancelOrderAsync(id, _currentUserService.UserId);
            return Ok(new { 
                data = order, 
                message = "Narudžba je uspješno otkazana." 
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
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error cancelling order {OrderId}", id);
            return StatusCode(500, new { message = "Greška pri otkazivanju narudžbe." });
        }
    }

    [HttpPost("{id}/refund")]
    public async Task<ActionResult<OrderDto>> RefundOrder(int id, [FromBody] RefundRequest? request = null)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            var reason = request?.Reason ?? "Korisnički zahtjev";
            var order = await _orderService.RefundOrderAsync(id, _currentUserService.UserId, reason);
            return Ok(new { 
                data = order, 
                message = "Refund je uspješno obrađen. Novac će biti vraćen na vašu karticu u roku od 5-10 radnih dana." 
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
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error refunding order {OrderId}", id);
            return StatusCode(500, new { message = "Greška pri obradi refund-a." });
        }
    }

    [HttpGet("{id}/tickets")]
    public async Task<ActionResult<List<TicketDto>>> GetOrderTickets(int id)
    {
        try
        {
            if (string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "Korisnik nije autentifikovan." });
            }

            var tickets = await _orderService.GetOrderTicketsAsync(id, _currentUserService.UserId);
            return Ok(tickets);
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
            _logger.LogError(ex, "Error getting tickets for order {OrderId}", id);
            return StatusCode(500, new { message = "Greška pri dohvatanju karata." });
        }
    }
}






