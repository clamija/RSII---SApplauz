using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Infrastructure.Services;

namespace SApplauz.Worker.Workers;

public class TicketExpirationService : BackgroundService
{
    private readonly ILogger<TicketExpirationService> _logger;
    private readonly IServiceProvider _serviceProvider;
    private readonly TimeSpan _checkInterval = TimeSpan.FromMinutes(7); // Pokreće se svakih 7 minuta (između 5-10)
    private readonly TimeSpan _expirationThreshold = TimeSpan.FromMinutes(15); // 15 minuta nakon početka predstave

    public TicketExpirationService(
        ILogger<TicketExpirationService> logger,
        IServiceProvider serviceProvider)
    {
        _logger = logger;
        _serviceProvider = serviceProvider;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("TicketExpirationService started. Checking for expired tickets every {Interval} minutes.", _checkInterval.TotalMinutes);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessExpiredTicketsAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while processing expired tickets");
            }

            // Čekaj prije sljedeće provjere
            await Task.Delay(_checkInterval, stoppingToken);
        }
    }

    private async Task ProcessExpiredTicketsAsync(CancellationToken stoppingToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var rabbitMQService = scope.ServiceProvider.GetRequiredService<IRabbitMQService>();

        // Pronađi Performances koje su počele prije više od 15 minuta (u lokalnom vremenu aplikacije)
        var cutoffTime = GetNowInAppTimeZone().Subtract(_expirationThreshold);
        
        var expiredPerformances = await dbContext.Performances
            .Where(p => p.StartTime <= cutoffTime)
            .Include(p => p.OrderItems)
                .ThenInclude(oi => oi.Tickets)
            .Include(p => p.OrderItems)
                .ThenInclude(oi => oi.Order)
            .Include(p => p.Show)
            .ToListAsync(stoppingToken);

        if (!expiredPerformances.Any())
        {
            _logger.LogDebug("No expired performances found. Cutoff time: {CutoffTime}", cutoffTime);
            return;
        }

        _logger.LogInformation("Found {Count} performances that started more than {Minutes} minutes ago", 
            expiredPerformances.Count, _expirationThreshold.TotalMinutes);

        int totalExpiredTickets = 0;

        foreach (var performance in expiredPerformances)
        {
            // Pronađi sve Tickets sa Status = NotScanned za ovu Performance
            var expiredTickets = performance.OrderItems
                .SelectMany(oi => oi.Tickets)
                .Where(t => t.Status == TicketStatus.NotScanned)
                .ToList();

            if (!expiredTickets.Any())
            {
                continue;
            }

            _logger.LogInformation(
                "Processing {Count} expired tickets for Performance {PerformanceId} (Show: {ShowTitle}, StartTime: {StartTime})",
                expiredTickets.Count,
                performance.Id,
                performance.Show.Title,
                performance.StartTime);

            foreach (var ticket in expiredTickets)
            {
                try
                {
                    // Postavi Status = Invalid
                    ticket.Status = TicketStatus.Invalid;

                    // Pronađi Order i User informacije
                    var orderItem = performance.OrderItems.First(oi => oi.Tickets.Contains(ticket));
                    var order = orderItem.Order;

                    // Pronađi User email i ime
                    var user = await dbContext.Users.FindAsync(new object[] { order.UserId }, stoppingToken);
                    
                    if (user == null)
                    {
                        _logger.LogWarning("User not found for Order {OrderId}, Ticket {TicketId}", order.Id, ticket.Id);
                        continue;
                    }

                    // Publish RabbitMQ poruku za email notifikacije
                    rabbitMQService.PublishTicketExpired(
                        ticketId: ticket.Id,
                        orderId: order.Id,
                        userId: order.UserId,
                        userEmail: user.Email ?? string.Empty,
                        userName: $"{user.FirstName} {user.LastName}".Trim(),
                        showId: performance.ShowId,
                        showTitle: performance.Show.Title,
                        performanceId: performance.Id,
                        performanceStartTime: performance.StartTime
                    );

                    _logger.LogInformation(
                        "Expired ticket {TicketId} for Performance {PerformanceId}. Published RabbitMQ message for email notification.",
                        ticket.Id,
                        performance.Id);

                    totalExpiredTickets++;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing expired ticket {TicketId}", ticket.Id);
                }
            }
        }

        // Sačuvaj promjene u bazi
        if (totalExpiredTickets > 0)
        {
            try
            {
                await dbContext.SaveChangesAsync(stoppingToken);
                _logger.LogInformation("Successfully expired {Count} tickets and saved changes to database", totalExpiredTickets);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error saving expired tickets to database");
            }
        }
        else
        {
            _logger.LogDebug("No tickets were expired in this cycle");
        }
    }

    private static DateTime GetNowInAppTimeZone()
    {
        var tz = GetAppTimeZone();
        return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
    }

    private static TimeZoneInfo GetAppTimeZone()
    {
        try { return TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo"); } catch { /* ignore */ }
        try { return TimeZoneInfo.FindSystemTimeZoneById("Central European Standard Time"); } catch { /* ignore */ }
        return TimeZoneInfo.Local;
    }
}
