using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Configurations;
using SApplauz.Infrastructure.Identity;
using SApplauz.Infrastructure.Services;
using SApplauz.Shared.DTOs;
using Stripe;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly ICurrentUserService _currentUserService;
    private readonly StripeSettings _stripeSettings;
    private readonly ILogger<PaymentsController> _logger;
    private readonly IServiceScopeFactory _serviceScopeFactory;

    public PaymentsController(
        IOrderService orderService,
        ICurrentUserService currentUserService,
        IOptions<StripeSettings> stripeSettings,
        ILogger<PaymentsController> logger,
        IServiceScopeFactory serviceScopeFactory)
    {
        _orderService = orderService;
        _currentUserService = currentUserService;
        _stripeSettings = stripeSettings.Value;
        _logger = logger;
        _serviceScopeFactory = serviceScopeFactory;
    }

    [HttpPost("create-intent")]
    [Authorize]
    public async Task<ActionResult<CreatePaymentIntentResponse>> CreatePaymentIntent([FromBody] CreatePaymentIntentRequest request)
    {
        try
        {
            var userId = _currentUserService.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
            var response = await _orderService.CreatePaymentIntentAsync(request.OrderId, userId);
            response.PublishableKey = _stripeSettings.PublishableKey;
            return Ok(response);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
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
            _logger.LogError(ex, "Error creating payment intent for OrderId: {OrderId}", request.OrderId);
            return StatusCode(500, new { message = "An error occurred while creating payment intent." });
        }
    }

    [HttpPost("confirm")]
    [Authorize]
    public async Task<ActionResult<OrderDto>> ConfirmPayment([FromBody] ConfirmPaymentRequest request)
    {
        try
        {
            var userId = _currentUserService.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
            var order = await _orderService.ProcessPaymentAsync(request.OrderId, request.PaymentIntentId, userId);
            return Ok(order);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
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
            _logger.LogError(ex, "Error confirming payment for OrderId: {OrderId}", request.OrderId);
            return StatusCode(500, new { message = "An error occurred while confirming payment." });
        }
    }

    [HttpPost("webhook")]
    [AllowAnonymous]
    public async Task<IActionResult> StripeWebhook()
    {
        var json = await new StreamReader(HttpContext.Request.Body).ReadToEndAsync();
        
        try
        {
            var stripeEvent = EventUtility.ConstructEvent(
                json,
                Request.Headers["Stripe-Signature"],
                _stripeSettings.WebhookSecret
            );

            _logger.LogInformation("Received Stripe webhook event: {EventType}, {EventId}", stripeEvent.Type, stripeEvent.Id);

            if (stripeEvent.Type == Events.PaymentIntentSucceeded)
            {
                var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
                if (paymentIntent != null)
                {
                    await HandlePaymentIntentSucceeded(paymentIntent);
                }
            }
            else if (stripeEvent.Type == Events.PaymentIntentPaymentFailed)
            {
                var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
                if (paymentIntent != null)
                {
                    await HandlePaymentIntentFailed(paymentIntent);
                }
            }
            else if (stripeEvent.Type == Events.ChargeRefunded)
            {
                var charge = stripeEvent.Data.Object as Charge;
                if (charge != null)
                {
                    await HandleChargeRefunded(charge);
                }
            }

            return Ok();
        }
        catch (StripeException ex)
        {
            _logger.LogError(ex, "Stripe webhook error");
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing Stripe webhook");
            return StatusCode(500, new { message = "An error occurred while processing webhook." });
        }
    }

    private async Task HandlePaymentIntentSucceeded(PaymentIntent paymentIntent)
    {
        // Extract order ID from metadata
        if (paymentIntent.Metadata.TryGetValue("orderId", out var orderIdStr) && int.TryParse(orderIdStr, out var orderId))
        {
            try
            {
                // Get order to find user
                var order = await _orderService.GetOrderByIdAsync(orderId);
                if (order != null && order.Status != "Paid")
                {
                    // Process payment (this will update order status and payment status)
                    await _orderService.ProcessPaymentAsync(orderId, paymentIntent.Id, order.UserId);
                    _logger.LogInformation("Processed payment for OrderId: {OrderId} via webhook", orderId);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing payment for OrderId: {OrderId} via webhook", orderId);
            }
        }
    }

    private Task HandlePaymentIntentFailed(PaymentIntent paymentIntent)
    {
        // Extract order ID from metadata
        if (paymentIntent.Metadata.TryGetValue("orderId", out var orderIdStr) && int.TryParse(orderIdStr, out var orderId))
        {
            _logger.LogWarning("Payment failed for OrderId: {OrderId}, PaymentIntentId: {PaymentIntentId}", orderId, paymentIntent.Id);
            // Payment status will be updated to Failed in ProcessPaymentAsync if called
            // Or you can add logic here to update payment status directly
        }
        return Task.CompletedTask;
    }

    private async Task HandleChargeRefunded(Charge charge)
    {
        try
        {
            // Extract PaymentIntentId from charge
            if (string.IsNullOrEmpty(charge.PaymentIntentId))
            {
                _logger.LogWarning("Charge refunded but no PaymentIntentId found. ChargeId: {ChargeId}", charge.Id);
                return;
            }

            var paymentIntentId = charge.PaymentIntentId;

            // Find order by PaymentIntentId
            using var scope = _serviceScopeFactory.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

            var payment = await dbContext.Payments
                .Include(p => p.Order)
                    .ThenInclude(o => o.OrderItems)
                        .ThenInclude(oi => oi.Performance)
                .Include(p => p.Order)
                    .ThenInclude(o => o.OrderItems)
                        .ThenInclude(oi => oi.Tickets)
                .Include(p => p.Order)
                    .ThenInclude(o => o.Institution)
                .FirstOrDefaultAsync(p => p.StripePaymentIntentId == paymentIntentId);

            if (payment == null)
            {
                _logger.LogWarning("Payment not found for PaymentIntentId: {PaymentIntentId}", paymentIntentId);
                return;
            }

            var order = payment.Order;

            // Idempotency check: ako je već refundiran, ne radimo ništa
            if (order.Status == OrderStatus.Refunded && payment.Status == PaymentStatus.Refunded)
            {
                _logger.LogInformation("Order {OrderId} already refunded. Skipping.", order.Id);
                return;
            }

            // Ažuriraj status narudžbe
            if (order.Status != OrderStatus.Refunded)
            {
                order.Status = OrderStatus.Refunded;
                order.UpdatedAt = DateTime.UtcNow;

                // Označi sve karte kao refundirane
                foreach (var orderItem in order.OrderItems)
                {
                    foreach (var ticket in orderItem.Tickets)
                    {
                        if (ticket.Status == TicketStatus.NotScanned)
                        {
                            ticket.Status = TicketStatus.Refunded;
                        }
                    }

                    // Oslobodi mjesta (povećaj AvailableSeats)
                    orderItem.Performance.AvailableSeats += orderItem.Quantity;
                }
            }

            // Ažuriraj status plaćanja
            if (payment.Status != PaymentStatus.Refunded)
            {
                payment.Status = PaymentStatus.Refunded;
            }

            await dbContext.SaveChangesAsync();

            // Publish RabbitMQ poruku za email notifikaciju
            var rabbitMQService = scope.ServiceProvider.GetRequiredService<IRabbitMQService>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();

            var user = await userManager.FindByIdAsync(order.UserId);
            if (user != null && rabbitMQService != null)
            {
                var refundId = charge.Refunds?.Data?.FirstOrDefault()?.Id ?? $"refund_{charge.Id}";
                var refundAmount = charge.Refunds?.Data?.Sum(r => r.Amount) / 100m ?? charge.AmountRefunded / 100m;

                rabbitMQService.PublishRefund(
                    orderId: order.Id,
                    userId: order.UserId,
                    userEmail: user.Email ?? string.Empty,
                    userName: user.UserName ?? "Korisnik",
                    refundAmount: refundAmount,
                    paymentIntentId: paymentIntentId,
                    refundId: refundId,
                    reason: "Stripe webhook - automatski refund"
                );

                _logger.LogInformation("Processed refund for OrderId: {OrderId} via webhook. ChargeId: {ChargeId}", order.Id, charge.Id);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing refund for ChargeId: {ChargeId} via webhook", charge.Id);
        }
    }
}

