using AutoMapper;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;
using System.Security.Cryptography;
using System.Text;
using Stripe;

namespace SApplauz.Application.Services;

public class OrderService : IOrderService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IMapper _mapper;
    private readonly IPerformanceService _performanceService;
    private readonly IRecommendationService? _recommendationService;
    private readonly SApplauz.Infrastructure.Services.IRabbitMQService? _rabbitMQService;
    private readonly UserManager<ApplicationUser>? _userManager;
    private readonly SApplauz.Infrastructure.Services.IStripeService? _stripeService;

    public OrderService(
        ApplicationDbContext dbContext,
        IMapper mapper,
        IPerformanceService performanceService,
        IRecommendationService? recommendationService = null,
        SApplauz.Infrastructure.Services.IRabbitMQService? rabbitMQService = null,
        UserManager<ApplicationUser>? userManager = null,
        SApplauz.Infrastructure.Services.IStripeService? stripeService = null)
    {
        _dbContext = dbContext;
        _mapper = mapper;
        _performanceService = performanceService;
        _recommendationService = recommendationService;
        _rabbitMQService = rabbitMQService;
        _userManager = userManager;
        _stripeService = stripeService;
    }

    public async Task<OrderDto?> GetOrderByIdAsync(int id)
    {
        var order = await _dbContext.Orders
            .Include(o => o.Institution)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Tickets)
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
        {
            return null;
        }

        var dto = _mapper.Map<OrderDto>(order);
        dto.InstitutionName = order.Institution.Name;
        
        var user = await _dbContext.Users.FindAsync(order.UserId);
        dto.UserName = user != null ? $"{user.FirstName} {user.LastName}" : "Nepoznat korisnik";
        
        dto.OrderItems = order.OrderItems.Select(oi =>
        {
            var itemDto = _mapper.Map<OrderItemDto>(oi);
            itemDto.PerformanceShowTitle = oi.Performance.Show.Title;
            itemDto.PerformanceStartTime = oi.Performance.StartTime;
            itemDto.Tickets = oi.Tickets.Select(t => _mapper.Map<TicketDto>(t)).ToList();
            return itemDto;
        }).ToList();
        
        return dto;
    }

    public async Task<OrderListResponse> GetUserOrdersAsync(string userId, int pageNumber, int pageSize)
    {
        var query = _dbContext.Orders
            .Include(o => o.Institution)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
            .Where(o => o.UserId == userId);

        var totalCount = await query.CountAsync();

        var orders = await query
            .OrderByDescending(o => o.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var userIds = orders.Select(o => o.UserId).Distinct().ToList();
        var userNames = await _dbContext.Users
            .Where(u => userIds.Contains(u.Id))
            .Select(u => new { u.Id, u.FirstName, u.LastName })
            .ToListAsync();
        var userNameDict = userNames.ToDictionary(
            x => x.Id,
            x => $"{x.FirstName} {x.LastName}".Trim());

        var orderDtos = orders.Select(order =>
        {
            var dto = _mapper.Map<OrderDto>(order);
            dto.InstitutionName = order.Institution.Name;
            dto.UserName = userNameDict.TryGetValue(order.UserId, out var name) ? name : "Nepoznat korisnik";
            dto.OrderItems = order.OrderItems.Select(oi =>
            {
                var itemDto = _mapper.Map<OrderItemDto>(oi);
                itemDto.PerformanceShowTitle = oi.Performance.Show.Title;
                itemDto.PerformanceStartTime = oi.Performance.StartTime;
                return itemDto;
            }).ToList();
            return dto;
        }).ToList();

        return new OrderListResponse
        {
            Orders = orderDtos,
            TotalCount = totalCount,
            PageNumber = pageNumber,
            PageSize = pageSize
        };
    }

    public async Task<OrderListResponse> GetInstitutionOrdersAsync(
        int? institutionId,
        int pageNumber,
        int pageSize,
        string? status = null,
        DateTime? startDate = null,
        DateTime? endDate = null)
    {
        var query = _dbContext.Orders
            .Include(o => o.Institution)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
            .AsQueryable();

        if (institutionId.HasValue)
        {
            query = query.Where(o => o.InstitutionId == institutionId.Value);
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            var s = status.Trim().ToLowerInvariant();
            query = s switch
            {
                "paid" => query.Where(o => o.Status == OrderStatus.Paid),
                "pending" => query.Where(o => o.Status == OrderStatus.Pending),
                "cancelled" => query.Where(o => o.Status == OrderStatus.Cancelled),
                "refunded" => query.Where(o => o.Status == OrderStatus.Refunded),
                _ => query
            };
        }

        if (startDate.HasValue)
        {
            query = query.Where(o => o.CreatedAt >= startDate.Value);
        }
        if (endDate.HasValue)
        {
            query = query.Where(o => o.CreatedAt <= endDate.Value);
        }

        var totalCount = await query.CountAsync();

        var orders = await query
            .OrderByDescending(o => o.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var userIds = orders.Select(o => o.UserId).Distinct().ToList();
        var userNames = await _dbContext.Users
            .Where(u => userIds.Contains(u.Id))
            .Select(u => new { u.Id, u.FirstName, u.LastName })
            .ToListAsync();
        var userNameDict = userNames.ToDictionary(
            x => x.Id,
            x => $"{x.FirstName} {x.LastName}".Trim());

        var orderDtos = orders.Select(order =>
        {
            var dto = _mapper.Map<OrderDto>(order);
            dto.InstitutionName = order.Institution.Name;
            dto.UserName = userNameDict.TryGetValue(order.UserId, out var name) ? name : "Nepoznat korisnik";
            dto.OrderItems = order.OrderItems.Select(oi =>
            {
                var itemDto = _mapper.Map<OrderItemDto>(oi);
                itemDto.PerformanceShowTitle = oi.Performance.Show.Title;
                itemDto.PerformanceStartTime = oi.Performance.StartTime;
                return itemDto;
            }).ToList();
            return dto;
        }).ToList();

        return new OrderListResponse
        {
            Orders = orderDtos,
            TotalCount = totalCount,
            PageNumber = pageNumber,
            PageSize = pageSize
        };
    }

    public async Task<OrderDto> CreateOrderAsync(string userId, CreateOrderRequest request)
    {
        var institution = await _dbContext.Institutions.FindAsync(request.InstitutionId);
        if (institution == null)
        {
            throw new KeyNotFoundException($"Institution with id {request.InstitutionId} not found.");
        }

        if (!request.OrderItems.Any())
        {
            throw new InvalidOperationException("Order must contain at least one item.");
        }

        var performanceIds = request.OrderItems.Select(oi => oi.PerformanceId).Distinct().ToList();
        var performances = await _dbContext.Performances
            .Include(p => p.Show)
            .Where(p => performanceIds.Contains(p.Id))
            .ToListAsync();

        if (performances.Count != performanceIds.Count)
        {
            var missingIds = performanceIds.Except(performances.Select(p => p.Id)).ToList();
            throw new KeyNotFoundException($"Performances with ids {string.Join(", ", missingIds)} not found.");
        }

        foreach (var orderItem in request.OrderItems)
        {
            var performance = performances.First(p => p.Id == orderItem.PerformanceId);
            
            if (performance.Show.InstitutionId != request.InstitutionId)
            {
                throw new InvalidOperationException($"Termin {orderItem.PerformanceId} ne pripada odabranoj instituciji.");
            }

            if (orderItem.Quantity <= 0)
            {
                throw new InvalidOperationException($"Količina karata mora biti veća od 0.");
            }

            if (performance.AvailableSeats < orderItem.Quantity)
            {
                if (performance.AvailableSeats == 0)
                {
                    throw new InvalidOperationException($"Termin za predstavu '{performance.Show.Title}' je rasprodan. Nema dostupnih karata.");
                }
                else
                {
                    throw new InvalidOperationException($"Neko je bio brži! Za termin '{performance.Show.Title}' je preostalo samo {performance.AvailableSeats} mjesta, a vi pokušavate kupiti {orderItem.Quantity}. Molimo smanjite količinu i pokušajte ponovo.");
                }
            }
        }

        decimal totalAmount = 0;
        foreach (var orderItem in request.OrderItems)
        {
            var performance = performances.First(p => p.Id == orderItem.PerformanceId);
            totalAmount += performance.Price * orderItem.Quantity;
        }

        Order order;
        using var transaction = await _dbContext.Database.BeginTransactionAsync();
        try
        {
            order = new Order
            {
                UserId = userId,
                InstitutionId = request.InstitutionId,
                TotalAmount = totalAmount,
                Status = OrderStatus.Pending,
                CreatedAt = DateTime.UtcNow
            };

            _dbContext.Orders.Add(order);
            await _dbContext.SaveChangesAsync();

            foreach (var orderItemRequest in request.OrderItems)
            {
                var performance = performances.First(p => p.Id == orderItemRequest.PerformanceId);
                
                var orderItem = new OrderItem
                {
                    OrderId = order.Id,
                    PerformanceId = orderItemRequest.PerformanceId,
                    Quantity = orderItemRequest.Quantity,
                    UnitPrice = performance.Price,
                };

                _dbContext.OrderItems.Add(orderItem);
            }

            await _dbContext.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }


        return await GetOrderByIdAsync(order.Id) ?? throw new InvalidOperationException("Failed to retrieve created order.");
    }

    public async Task<OrderDto> CancelOrderAsync(int id, string userId)
    {
        var order = await _dbContext.Orders
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Performance)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Tickets)
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
        {
            throw new KeyNotFoundException($"Order with id {id} not found.");
        }

        if (order.UserId != userId)
        {
            throw new UnauthorizedAccessException($"User does not have permission to cancel order {id}.");
        }

        if (order.Status == OrderStatus.Cancelled)
        {
            throw new InvalidOperationException($"Order {id} is already cancelled.");
        }

        if (order.Status == OrderStatus.Paid)
        {
            throw new InvalidOperationException($"Cannot cancel paid order {id}. Refund is required.");
        }

        foreach (var orderItem in order.OrderItems)
        {
            foreach (var ticket in orderItem.Tickets)
            {
                if (ticket.Status == TicketStatus.NotScanned)
                {
                    ticket.Status = TicketStatus.Invalid;
                }
            }
        }

        order.Status = OrderStatus.Cancelled;
        order.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync();

        return await GetOrderByIdAsync(order.Id) ?? throw new InvalidOperationException("Failed to retrieve cancelled order.");
    }

    public async Task<OrderDto> RefundOrderAsync(int id, string userId, string reason = "Korisnički zahtjev")
    {
        if (_stripeService == null)
        {
            throw new InvalidOperationException("Stripe service is not configured.");
        }

        if (_rabbitMQService == null)
        {
            throw new InvalidOperationException("RabbitMQ service is not configured.");
        }

        if (_userManager == null)
        {
            throw new InvalidOperationException("User manager is not configured.");
        }

        var order = await _dbContext.Orders
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Performance)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Tickets)
            .Include(o => o.Payments)
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
        {
            throw new KeyNotFoundException($"Order with id {id} not found.");
        }

        if (order.UserId != userId)
        {
            throw new UnauthorizedAccessException($"User does not have permission to refund order {id}.");
        }

        if (order.Status != OrderStatus.Paid)
        {
            throw new InvalidOperationException($"Order {id} cannot be refunded. Only paid orders can be refunded. Current status: {order.Status}");
        }

        var hasScannedTickets = order.OrderItems
            .SelectMany(oi => oi.Tickets)
            .Any(t => t.Status == TicketStatus.Scanned);

        if (hasScannedTickets)
        {
            throw new InvalidOperationException("Jedna od karata iz Vaše narudžbe je već skenirana, pa nije moguće obaviti refundaciju.");
        }

        var payment = order.Payments
            .FirstOrDefault(p => p.Status == PaymentStatus.Succeeded && !string.IsNullOrEmpty(p.StripePaymentIntentId));

        if (payment == null || string.IsNullOrEmpty(payment.StripePaymentIntentId))
        {
            throw new InvalidOperationException($"Order {id} does not have a valid payment intent for refund.");
        }

        var refundSucceeded = await _stripeService.RefundPaymentAsync(payment.StripePaymentIntentId, null);

        if (!refundSucceeded)
        {
            throw new InvalidOperationException($"Failed to process refund for order {id}. Please try again later.");
        }

        order.Status = OrderStatus.Refunded;
        order.UpdatedAt = DateTime.UtcNow;

        payment.Status = PaymentStatus.Refunded;

        foreach (var orderItem in order.OrderItems)
        {
            foreach (var ticket in orderItem.Tickets)
            {
                if (ticket.Status == TicketStatus.NotScanned)
                {
                    ticket.Status = TicketStatus.Refunded;
                }
            }

            orderItem.Performance.AvailableSeats += orderItem.Quantity;
        }

        await _dbContext.SaveChangesAsync();

        var user = await _userManager.FindByIdAsync(userId);
        if (user != null)
        {
            var refundId = $"refund_{payment.StripePaymentIntentId}_{DateTime.UtcNow:yyyyMMddHHmmss}";
            
            _rabbitMQService.PublishRefund(
                orderId: order.Id,
                userId: userId,
                userEmail: user.Email ?? string.Empty,
                userName: user.UserName ?? "Korisnik",
                refundAmount: order.TotalAmount,
                paymentIntentId: payment.StripePaymentIntentId,
                refundId: refundId,
                reason: reason
            );
        }

        return await GetOrderByIdAsync(order.Id) ?? throw new InvalidOperationException("Failed to retrieve refunded order.");
    }

    public async Task<List<TicketDto>> GetOrderTicketsAsync(int orderId, string userId)
    {
        var order = await _dbContext.Orders
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Tickets)
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
                        .ThenInclude(s => s.Institution)
            .FirstOrDefaultAsync(o => o.Id == orderId);

        if (order == null)
        {
            throw new KeyNotFoundException($"Order with id {orderId} not found.");
        }

        if (order.UserId != userId)
        {
            throw new UnauthorizedAccessException($"User does not have permission to view tickets for order {orderId}.");
        }

        if (order.Status == OrderStatus.Pending)
        {
            return new List<TicketDto>();
        }

        var tickets = order.OrderItems
            .SelectMany(oi => oi.Tickets)
            .ToList();

        return tickets.Select(t =>
        {
            var dto = _mapper.Map<TicketDto>(t);
            var orderItem = order.OrderItems.First(oi => oi.Tickets.Contains(t));
            dto.ShowTitle = orderItem.Performance.Show.Title;
            dto.PerformanceStartTime = orderItem.Performance.StartTime;
            dto.InstitutionName = orderItem.Performance.Show.Institution.Name;
            dto.Status = t.Status.ToString();
            return dto;
        }).ToList();
    }

    private string GenerateQRCode(int orderItemId, int ticketNumber)
    {
        var timestamp = DateTime.UtcNow.Ticks;
        var random = RandomNumberGenerator.GetInt32(1000, 9999);
        var data = $"TICKET_{orderItemId}_{ticketNumber}_{timestamp}_{random}";
        
        using var sha256 = SHA256.Create();
        var hashBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(data));
        var hashString = Convert.ToBase64String(hashBytes).Replace("/", "_").Replace("+", "-").Substring(0, 32);
        
        return $"TICKET_{orderItemId}_{ticketNumber}_{hashString}";
    }

    public async Task<CreatePaymentIntentResponse> CreatePaymentIntentAsync(int orderId, string userId)
    {
        var order = await _dbContext.Orders
            .FirstOrDefaultAsync(o => o.Id == orderId);

        if (order == null)
        {
            throw new KeyNotFoundException($"Order with id {orderId} not found.");
        }

        if (order.UserId != userId)
        {
            throw new UnauthorizedAccessException($"User does not have permission to pay for order {orderId}.");
        }

        if (order.Status != OrderStatus.Pending)
        {
            throw new InvalidOperationException($"Order {orderId} is not in Pending status. Current status: {order.Status}");
        }

        if (_stripeService == null)
        {
            throw new InvalidOperationException("Stripe service is not configured.");
        }

        var existingPayment = await _dbContext.Payments
            .FirstOrDefaultAsync(p => p.OrderId == orderId && 
                                      (p.Status == PaymentStatus.Initiated || p.Status == PaymentStatus.Failed));

        string clientSecret;
        string paymentIntentId;

        if (existingPayment != null && !string.IsNullOrEmpty(existingPayment.StripePaymentIntentId))
        {
            try
            {
                var stripeService = new Stripe.PaymentIntentService();
                var existingIntent = await stripeService.GetAsync(existingPayment.StripePaymentIntentId);
                
                if (existingIntent.Status == "requires_payment_method" || existingIntent.Status == "requires_confirmation")
                {
                    paymentIntentId = existingPayment.StripePaymentIntentId;
                    clientSecret = existingIntent.ClientSecret ?? throw new InvalidOperationException("Postojeći PaymentIntent nema client secret. Molimo pokušajte ponovo.");
                }
                else
                {
                    clientSecret = await _stripeService.CreatePaymentIntentAsync(orderId, order.TotalAmount);
                    var parts = clientSecret.Split(new[] { "_secret_" }, StringSplitOptions.None);
                    paymentIntentId = parts.Length > 0 ? parts[0] : clientSecret;
                    
                    existingPayment.StripePaymentIntentId = paymentIntentId;
                    existingPayment.Status = PaymentStatus.Initiated;
                    await _dbContext.SaveChangesAsync();
                }
            }
            catch
            {
                try
                {
                    clientSecret = await _stripeService.CreatePaymentIntentAsync(orderId, order.TotalAmount);
                    var parts = clientSecret.Split(new[] { "_secret_" }, StringSplitOptions.None);
                    paymentIntentId = parts.Length > 0 ? parts[0] : clientSecret;
                    
                    existingPayment.StripePaymentIntentId = paymentIntentId;
                    existingPayment.Status = PaymentStatus.Initiated;
                    await _dbContext.SaveChangesAsync();
                }
                catch (Exception ex)
                {
                    throw new InvalidOperationException($"Greška pri kreiranju payment intent-a. Molimo pokušajte ponovo. Detalji: {ex.Message}");
                }
            }
        }
        else
        {
            try
            {
                clientSecret = await _stripeService.CreatePaymentIntentAsync(orderId, order.TotalAmount);
                
                var parts = clientSecret.Split(new[] { "_secret_" }, StringSplitOptions.None);
                paymentIntentId = parts.Length > 0 ? parts[0] : clientSecret;

                var payment = new Payment
                {
                    OrderId = orderId,
                    StripePaymentIntentId = paymentIntentId,
                    Amount = order.TotalAmount,
                    Status = PaymentStatus.Initiated,
                    CreatedAt = DateTime.UtcNow
                };

                _dbContext.Payments.Add(payment);
                await _dbContext.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Greška pri inicijalizaciji plaćanja. Molimo pokušajte ponovo. Detalji: {ex.Message}");
            }
        }

        return new CreatePaymentIntentResponse
        {
            ClientSecret = clientSecret,
            PaymentIntentId = paymentIntentId,
            PublishableKey = string.Empty // Will be set from configuration in controller
        };
    }

    public async Task<OrderDto> ProcessPaymentAsync(int orderId, string paymentIntentId, string userId)
    {
        var order = await _dbContext.Orders
            .Include(o => o.Payments)
            .FirstOrDefaultAsync(o => o.Id == orderId);

        if (order == null)
        {
            throw new KeyNotFoundException($"Order with id {orderId} not found.");
        }

        if (order.UserId != userId)
        {
            throw new UnauthorizedAccessException($"User does not have permission to process payment for order {orderId}.");
        }

        if (order.Status == OrderStatus.Paid)
        {
            return await GetOrderByIdAsync(order.Id) ?? throw new InvalidOperationException("Failed to retrieve order.");
        }

        var payment = order.Payments.FirstOrDefault(p => p.StripePaymentIntentId == paymentIntentId);
        if (payment == null)
        {
            throw new KeyNotFoundException($"Payment with PaymentIntentId {paymentIntentId} not found for order {orderId}.");
        }

        if (_stripeService == null)
        {
            throw new InvalidOperationException("Stripe service is not configured.");
        }

        var stripeService = new Stripe.PaymentIntentService();
        var stripePaymentIntent = await stripeService.GetAsync(paymentIntentId);
        
        if (stripePaymentIntent.Status == "succeeded")
        {
        }
        else if (stripePaymentIntent.Status == "requires_confirmation" || stripePaymentIntent.Status == "requires_payment_method")
        {
            var confirmed = await _stripeService.ConfirmPaymentAsync(paymentIntentId);
            
            if (!confirmed)
            {
                payment.Status = PaymentStatus.Failed;
                await _dbContext.SaveChangesAsync();
                throw new InvalidOperationException("Potvrda plaćanja nije uspjela. Molimo pokušajte ponovo ili kontaktirajte podršku.");
            }
        }
        else
        {
            payment.Status = PaymentStatus.Failed;
            await _dbContext.SaveChangesAsync();
            throw new InvalidOperationException($"Plaćanje je u neočekivanom stanju: {stripePaymentIntent.Status}. Molimo kontaktirajte podršku.");
        }

        payment.Status = PaymentStatus.Succeeded;
        
        order.Status = OrderStatus.Paid;
        order.UpdatedAt = DateTime.UtcNow;

        var orderItems = await _dbContext.OrderItems
            .Include(oi => oi.Performance)
                .ThenInclude(p => p.Show)
            .Where(oi => oi.OrderId == orderId)
            .ToListAsync();

        using var transaction = await _dbContext.Database.BeginTransactionAsync();
        try
        {
            foreach (var orderItem in orderItems)
            {
                var performance = await _dbContext.Performances
                    .Include(p => p.Show)
                    .FirstOrDefaultAsync(p => p.Id == orderItem.PerformanceId);
                
                if (performance == null)
                {
                    throw new KeyNotFoundException($"Termin {orderItem.PerformanceId} nije pronađen.");
                }
                
                if (performance.AvailableSeats < orderItem.Quantity)
                {
                    payment.Status = PaymentStatus.Failed;
                    order.Status = OrderStatus.Pending;
                    
                    await _dbContext.SaveChangesAsync();
                    await transaction.RollbackAsync();
                    
                    if (performance.AvailableSeats == 0)
                    {
                        throw new InvalidOperationException(
                            $"Žao nam je! Plaćanje je uspješno, ali termin za predstavu '{performance.Show.Title}' je rasprodan dok ste vi obavljali plaćanje. " +
                            $"Vaše sredstva će biti vraćena automatski. Molimo odaberite drugi termin.");
                    }
                    else
                    {
                        throw new InvalidOperationException(
                            $"Neko je bio brži! Plaćanje je uspješno, ali za termin '{performance.Show.Title}' je preostalo samo {performance.AvailableSeats} mjesta, " +
                            $"a vi ste kupili {orderItem.Quantity}. Vaše sredstva će biti vraćena automatski. Molimo odaberite drugi termin ili smanjite količinu.");
                    }
                }
            }

            foreach (var orderItem in orderItems)
            {
                var performance = await _dbContext.Performances
                    .FirstOrDefaultAsync(p => p.Id == orderItem.PerformanceId);
                
                if (performance == null)
                {
                    throw new KeyNotFoundException($"Termin {orderItem.PerformanceId} nije pronađen.");
                }

                for (int i = 0; i < orderItem.Quantity; i++)
                {
                    var qrCode = GenerateQRCode(orderItem.Id, i + 1);
                    
                    var ticket = new Ticket
                    {
                        OrderItemId = orderItem.Id,
                        QRCode = qrCode,
                        Status = TicketStatus.NotScanned,
                        CreatedAt = DateTime.UtcNow
                    };

                    _dbContext.Tickets.Add(ticket);
                }

                performance.AvailableSeats -= orderItem.Quantity;
                performance.UpdatedAt = DateTime.UtcNow;
            }

            await _dbContext.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch (InvalidOperationException)
        {
            throw;
        }
        catch
        {
            await transaction.RollbackAsync();
            
            payment.Status = PaymentStatus.Failed;
            order.Status = OrderStatus.Pending;
            await _dbContext.SaveChangesAsync();
            
            throw;
        }

        if (_recommendationService != null)
        {
            try
            {
                var showIds = orderItems
                    .Select(oi => oi.Performance.ShowId)
                    .Distinct()
                    .ToList();

                foreach (var showId in showIds)
                {
                    await _recommendationService.UpdateUserPreferencesAsync(userId, showId);
                }
                
                await _recommendationService.InvalidateUserCacheAsync(userId);
            }
            catch
            {
            }
        }

        if (_rabbitMQService != null && _userManager != null)
        {
            try
            {
                var user = await _userManager.FindByIdAsync(userId);
                if (user != null)
                {
                    _rabbitMQService.PublishOrderPaid(
                        order.Id,
                        userId,
                        user.Email ?? string.Empty,
                        $"{user.FirstName} {user.LastName}",
                        order.TotalAmount,
                        paymentIntentId
                    );
                }
            }
            catch
            {
            }
        }

        return await GetOrderByIdAsync(order.Id) ?? throw new InvalidOperationException("Failed to retrieve order.");
    }
}

