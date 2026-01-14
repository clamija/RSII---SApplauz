using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;

namespace SApplauz.Application.Services;

/// <summary>
/// Background servis koji automatski poništava karte 15 minuta nakon početka predstave
/// ako nisu skenirane.
/// </summary>
public class TicketExpirationService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<TicketExpirationService> _logger;
    private readonly TimeSpan _checkInterval = TimeSpan.FromMinutes(5); // Provjerava svakih 5 minuta
    private readonly TimeSpan _expirationWindow = TimeSpan.FromMinutes(15); // 15 minuta nakon početka

    public TicketExpirationService(
        IServiceProvider serviceProvider,
        ILogger<TicketExpirationService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("TicketExpirationService je pokrenut.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessExpiredTicketsAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Greška pri procesiranju isteklih karata.");
            }

            await Task.Delay(_checkInterval, stoppingToken);
        }

        _logger.LogInformation("TicketExpirationService je zaustavljen.");
    }

    private async Task ProcessExpiredTicketsAsync()
    {
        using var scope = _serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        try
        {
            var now = GetNowInAppTimeZone();
            var expirationTime = now.Subtract(_expirationWindow); // 15 minuta unazad

            // Pronađi sve karte koje:
            // 1. Imaju status NotScanned
            // 2. Pripadaju Performancima čiji je StartTime + 15 minuta < sada
            var expiredTickets = await dbContext.Tickets
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Performance)
                .Where(t => t.Status == TicketStatus.NotScanned &&
                           t.OrderItem.Performance.StartTime.AddMinutes(15) < now)
                .ToListAsync();

            if (expiredTickets.Any())
            {
                _logger.LogInformation("Pronađeno {Count} isteklih karata za poništavanje.", expiredTickets.Count);

                foreach (var ticket in expiredTickets)
                {
                    ticket.Status = TicketStatus.Invalid;
                    _logger.LogDebug(
                        "Karta ID {TicketId} (QR: {QRCode}) je poništena. Performance StartTime: {StartTime}",
                        ticket.Id, 
                        ticket.QRCode, 
                        ticket.OrderItem.Performance.StartTime);
                }

                await dbContext.SaveChangesAsync();
                _logger.LogInformation("Uspešno poništeno {Count} karata.", expiredTickets.Count);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Greška pri procesiranju isteklih karata.");
            throw;
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

