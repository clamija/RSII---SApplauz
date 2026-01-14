using AutoMapper;
using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Services;

public class TicketService : ITicketService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IMapper _mapper;
    private readonly SApplauz.Infrastructure.Services.IRabbitMQService? _rabbitMQService;

    public TicketService(
        ApplicationDbContext dbContext, 
        IMapper mapper,
        SApplauz.Infrastructure.Services.IRabbitMQService? rabbitMQService = null)
    {
        _dbContext = dbContext;
        _mapper = mapper;
        _rabbitMQService = rabbitMQService;
    }

    public async Task<ValidateTicketResponse> ValidateTicketAsync(string qrCode, int? institutionId = null)
    {
        var ticket = await _dbContext.Tickets
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Order)
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
                        .ThenInclude(s => s.Institution)
            .FirstOrDefaultAsync(t => t.QRCode == qrCode);

        if (ticket == null)
        {
            return new ValidateTicketResponse
            {
                IsValid = false,
                Message = "Karta sa datim QR kodom nije pronađena."
            };
        }

        if (ticket.Status == TicketStatus.Refunded)
        {
            var refundedDto = _mapper.Map<TicketDto>(ticket);
            refundedDto.ShowTitle = ticket.OrderItem.Performance.Show.Title;
            refundedDto.PerformanceStartTime = ticket.OrderItem.Performance.StartTime;
            refundedDto.InstitutionName = ticket.OrderItem.Performance.Show.Institution.Name;
            refundedDto.InstitutionId = ticket.OrderItem.Performance.Show.InstitutionId;
            refundedDto.Status = ticket.Status.ToString();
            refundedDto.UserFullName = await GetTicketUserFullNameAsync(ticket.OrderItem.Order.UserId);
            return new ValidateTicketResponse
            {
                IsValid = false,
                Message = "Karta je refundirana.",
                Ticket = refundedDto
            };
        }

        if (ticket.Status == TicketStatus.Scanned)
        {
            var scannedDto = _mapper.Map<TicketDto>(ticket);
            scannedDto.ShowTitle = ticket.OrderItem.Performance.Show.Title;
            scannedDto.PerformanceStartTime = ticket.OrderItem.Performance.StartTime;
            scannedDto.InstitutionName = ticket.OrderItem.Performance.Show.Institution.Name;
            scannedDto.InstitutionId = ticket.OrderItem.Performance.Show.InstitutionId;
            scannedDto.Status = ticket.Status.ToString();
            scannedDto.UserFullName = await GetTicketUserFullNameAsync(ticket.OrderItem.Order.UserId);
            return new ValidateTicketResponse
            {
                IsValid = false,
                Message = "Karta je već skenirana.",
                Ticket = scannedDto
            };
        }

        if (ticket.Status == TicketStatus.Invalid)
        {
            var invalidDto = _mapper.Map<TicketDto>(ticket);
            invalidDto.ShowTitle = ticket.OrderItem.Performance.Show.Title;
            invalidDto.PerformanceStartTime = ticket.OrderItem.Performance.StartTime;
            invalidDto.InstitutionName = ticket.OrderItem.Performance.Show.Institution.Name;
            invalidDto.InstitutionId = ticket.OrderItem.Performance.Show.InstitutionId;
            invalidDto.Status = ticket.Status.ToString();
            invalidDto.UserFullName = await GetTicketUserFullNameAsync(ticket.OrderItem.Order.UserId);
            return new ValidateTicketResponse
            {
                IsValid = false,
                Message = "Karta je nevažeća.",
                Ticket = invalidDto
            };
        }

        if (ticket.OrderItem.Order.Status != OrderStatus.Paid)
        {
            var unpaidDto = _mapper.Map<TicketDto>(ticket);
            unpaidDto.ShowTitle = ticket.OrderItem.Performance.Show.Title;
            unpaidDto.PerformanceStartTime = ticket.OrderItem.Performance.StartTime;
            unpaidDto.InstitutionName = ticket.OrderItem.Performance.Show.Institution.Name;
            unpaidDto.InstitutionId = ticket.OrderItem.Performance.Show.InstitutionId;
            unpaidDto.Status = ticket.Status.ToString();
            unpaidDto.UserFullName = await GetTicketUserFullNameAsync(ticket.OrderItem.Order.UserId);
            return new ValidateTicketResponse
            {
                IsValid = false,
                Message = "Karta nije plaćena.",
                Ticket = unpaidDto
            };
        }

        if (institutionId.HasValue)
        {
            if (ticket.OrderItem.Performance.Show.InstitutionId != institutionId.Value)
            {
                var instDto = _mapper.Map<TicketDto>(ticket);
                instDto.ShowTitle = ticket.OrderItem.Performance.Show.Title;
                instDto.PerformanceStartTime = ticket.OrderItem.Performance.StartTime;
                instDto.InstitutionName = ticket.OrderItem.Performance.Show.Institution.Name;
                instDto.InstitutionId = ticket.OrderItem.Performance.Show.InstitutionId;
                instDto.Status = ticket.Status.ToString();
                instDto.UserFullName = await GetTicketUserFullNameAsync(ticket.OrderItem.Order.UserId);
                return new ValidateTicketResponse
                {
                    IsValid = false,
                    Message = "Karta ne pripada ovoj instituciji.",
                    Ticket = instDto
                };
            }
        }

        var performance = ticket.OrderItem.Performance;
        var now = GetNowInAppTimeZone();
        var startTime = performance.StartTime;
        var validFrom = startTime.AddMinutes(-120);
        var validTo = startTime.AddMinutes(15);

        if (now < validFrom)
        {
            var earlyDto = _mapper.Map<TicketDto>(ticket);
            earlyDto.ShowTitle = performance.Show.Title;
            earlyDto.PerformanceStartTime = performance.StartTime;
            earlyDto.InstitutionName = performance.Show.Institution.Name;
            earlyDto.InstitutionId = performance.Show.InstitutionId;
            earlyDto.Status = ticket.Status.ToString();
            earlyDto.UserFullName = await GetTicketUserFullNameAsync(ticket.OrderItem.Order.UserId);
            return new ValidateTicketResponse
            {
                IsValid = false,
                Message = $"Karta može biti skenirana najranije 120 minuta prije početka predstave.",
                Ticket = earlyDto
            };
        }

        if (now > validTo)
        {
            ticket.Status = TicketStatus.Invalid;
            await _dbContext.SaveChangesAsync();

            return new ValidateTicketResponse
            {
                IsValid = false,
                Message = "Karta je istekla (prošlo je više od 15 minuta od početka predstave).",
                Ticket = new TicketDto
                {
                    Id = ticket.Id,
                    OrderId = ticket.OrderItem.OrderId,
                    OrderItemId = ticket.OrderItemId,
                    QRCode = ticket.QRCode,
                    Status = ticket.Status.ToString(),
                    ScannedAt = ticket.ScannedAt,
                    CreatedAt = ticket.CreatedAt,
                    ShowTitle = performance.Show.Title,
                    PerformanceStartTime = performance.StartTime,
                    InstitutionName = performance.Show.Institution.Name,
                    InstitutionId = performance.Show.InstitutionId,
                    UserFullName = await GetTicketUserFullNameAsync(ticket.OrderItem.Order.UserId)
                }
            };
        }

        ticket.Status = TicketStatus.Scanned;
        // ScannedAt spremamo u "app lokalnom" vremenu (Europe/Sarajevo) kao Unspecified,
        // da klijenti ne dobiju +1h/+2h pomak zbog različitih interpretacija DateTime kind-a.
        var scannedLocal = GetNowInAppTimeZone();
        ticket.ScannedAt = DateTime.SpecifyKind(scannedLocal, DateTimeKind.Unspecified);
        await _dbContext.SaveChangesAsync();

        if (_rabbitMQService != null)
        {
            try
            {
                _rabbitMQService.PublishTicketScanned(
                    ticket.Id,
                    ticket.QRCode,
                    performance.Show.Id,
                    performance.Show.Title
                );
            }
            catch
            {
            }
        }

        var ticketDto = _mapper.Map<TicketDto>(ticket);
        ticketDto.ShowTitle = performance.Show.Title;
        ticketDto.PerformanceStartTime = performance.StartTime;
        ticketDto.InstitutionName = performance.Show.Institution.Name;
        ticketDto.InstitutionId = performance.Show.InstitutionId;
        ticketDto.Status = ticket.Status.ToString();
        ticketDto.UserFullName = await GetTicketUserFullNameAsync(ticket.OrderItem.Order.UserId);

        return new ValidateTicketResponse
        {
            IsValid = true,
            Message = "Karta je uspješno validirana.",
            Ticket = ticketDto
        };
    }

    public async Task<List<TicketDto>> GetUserTicketsAsync(string userId)
    {
        var tickets = await _dbContext.Tickets
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Order)
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
                        .ThenInclude(s => s.Institution)
            .Where(t => t.OrderItem.Order.UserId == userId)
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();

        var now = GetNowInAppTimeZone();
        var changed = false;
        foreach (var t in tickets)
        {
            changed |= TryRecomputeTicketStatus(t, now);
        }
        if (changed)
        {
            await _dbContext.SaveChangesAsync();
        }

        return tickets.Select(t =>
        {
            var dto = _mapper.Map<TicketDto>(t);
            dto.ShowTitle = t.OrderItem.Performance.Show.Title;
            dto.PerformanceStartTime = t.OrderItem.Performance.StartTime;
            dto.InstitutionName = t.OrderItem.Performance.Show.Institution.Name;
            dto.InstitutionId = t.OrderItem.Performance.Show.InstitutionId;
            dto.Status = t.Status.ToString();
            return dto;
        }).ToList();
    }

    public async Task<TicketDto?> GetTicketByQRCodeAsync(string qrCode)
    {
        var ticket = await _dbContext.Tickets
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Order)
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
                        .ThenInclude(s => s.Institution)
            .FirstOrDefaultAsync(t => t.QRCode == qrCode);

        if (ticket == null)
        {
            return null;
        }

        var now = GetNowInAppTimeZone();
        if (TryRecomputeTicketStatus(ticket, now))
        {
            await _dbContext.SaveChangesAsync();
        }

        var dto = _mapper.Map<TicketDto>(ticket);
        dto.ShowTitle = ticket.OrderItem.Performance.Show.Title;
        dto.PerformanceStartTime = ticket.OrderItem.Performance.StartTime;
        dto.InstitutionName = ticket.OrderItem.Performance.Show.Institution.Name;
        dto.InstitutionId = ticket.OrderItem.Performance.Show.InstitutionId;
        dto.Status = ticket.Status.ToString();
        dto.UserFullName = await GetTicketUserFullNameAsync(ticket.OrderItem.Order.UserId);
        return dto;
    }

    private async Task<string> GetTicketUserFullNameAsync(string? userId)
    {
        if (string.IsNullOrWhiteSpace(userId)) return string.Empty;
        var user = await _dbContext.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null) return string.Empty;
        return $"{user.FirstName} {user.LastName}".Trim();
    }

    public async Task<List<TicketDto>> GetPaidTicketsAsync(int? institutionId = null, string? status = null)
    {
        var query = _dbContext.Tickets
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Order)
            .Include(t => t.OrderItem)
                .ThenInclude(oi => oi.Performance)
                    .ThenInclude(p => p.Show)
                        .ThenInclude(s => s.Institution)
            .AsQueryable();

        query = query.Where(t => t.OrderItem.Order.Status == OrderStatus.Paid);

        if (institutionId.HasValue)
        {
            query = query.Where(t => t.OrderItem.Performance.Show.InstitutionId == institutionId.Value);
        }

        var tickets = await query
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();

        var now = GetNowInAppTimeZone();
        var changed = false;
        foreach (var t in tickets)
        {
            changed |= TryRecomputeTicketStatus(t, now);
        }
        if (changed)
        {
            await _dbContext.SaveChangesAsync();
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            var normalizedStatus = status.Trim();
            if (Enum.TryParse<TicketStatus>(normalizedStatus, ignoreCase: true, out var parsedStatus))
            {
                tickets = tickets.Where(t => t.Status == parsedStatus).ToList();
            }
        }

        return tickets.Select(t =>
        {
            var dto = _mapper.Map<TicketDto>(t);
            dto.ShowTitle = t.OrderItem.Performance.Show.Title;
            dto.PerformanceStartTime = t.OrderItem.Performance.StartTime;
            dto.InstitutionName = t.OrderItem.Performance.Show.Institution.Name;
            dto.InstitutionId = t.OrderItem.Performance.Show.InstitutionId;
            dto.Status = t.Status.ToString();
            return dto;
        }).ToList();
    }

    private static DateTime GetNowInAppTimeZone()
    {
        var tz = GetAppTimeZone();
        return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
    }

    private static TimeZoneInfo GetAppTimeZone()
    {
            try { return TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo"); } catch { }
        try { return TimeZoneInfo.FindSystemTimeZoneById("Central European Standard Time"); } catch { }
        return TimeZoneInfo.Local;
    }

    private static bool TryRecomputeTicketStatus(Ticket ticket, DateTime nowInAppTz)
    {
        if (ticket.Status == TicketStatus.Scanned) return false;
        if (ticket.Status == TicketStatus.Refunded) return false;

        var start = ticket.OrderItem?.Performance?.StartTime;
        if (start == null) return false;

        var isExpired = start.Value.AddMinutes(15) < nowInAppTz;

        if (ticket.Status == TicketStatus.NotScanned && isExpired)
        {
            ticket.Status = TicketStatus.Invalid;
            return true;
        }

        if (ticket.Status == TicketStatus.Invalid && !isExpired && ticket.ScannedAt == null)
        {
            ticket.Status = TicketStatus.NotScanned;
            return true;
        }

        return false;
    }
}




