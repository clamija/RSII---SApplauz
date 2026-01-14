using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SApplauz.Infrastructure.Configurations;

namespace SApplauz.Infrastructure.Services;

public class EmailService : IEmailService
{
    private readonly SmtpSettings _settings;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IOptions<SmtpSettings> settings, ILogger<EmailService> logger)
    {
        _settings = settings.Value;
        _logger = logger;
    }

    public async Task<bool> SendEmailAsync(string toEmail, string toName, string subject, string htmlBody, string? plainTextBody = null)
    {
        try
        {
            using var client = new SmtpClient(_settings.Host, _settings.Port)
            {
                EnableSsl = _settings.UseSsl,
                Credentials = new NetworkCredential(_settings.Username, _settings.Password)
            };

            using var message = new MailMessage
            {
                From = new MailAddress(_settings.FromEmail, _settings.FromName),
                Subject = subject,
                Body = htmlBody,
                IsBodyHtml = true
            };

            if (!string.IsNullOrEmpty(_settings.ForceRecipient))
            {
                message.To.Add(new MailAddress(_settings.ForceRecipient, _settings.FromName));
            }
            else
            {
                message.To.Add(new MailAddress(toEmail, toName));
            }

            // Add plain text alternative if provided
            if (!string.IsNullOrEmpty(plainTextBody))
            {
                var plainTextView = AlternateView.CreateAlternateViewFromString(plainTextBody, null, "text/plain");
                message.AlternateViews.Add(plainTextView);
            }

            await client.SendMailAsync(message);

            _logger.LogInformation("Email sent successfully to {ToEmail} with subject: {Subject}", toEmail, subject);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send email to {ToEmail} with subject: {Subject}", toEmail, subject);
            return false;
        }
    }

    public async Task<bool> SendOrderCreatedEmailAsync(string toEmail, string toName, int orderId, decimal totalAmount)
    {
        var subject = $"Narudžba #{orderId} kreirana - SApplauz";
        var htmlBody = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #6c5ce7; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }}
        .content {{ background-color: #f8f9fa; padding: 30px; border-radius: 0 0 5px 5px; }}
        .order-info {{ background-color: white; padding: 20px; border-radius: 5px; margin: 20px 0; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>SApplauz</h1>
        </div>
        <div class='content'>
            <h2>Hvala vam na narudžbi!</h2>
            <p>Poštovani/na {toName},</p>
            <p>Vaša narudžba je uspješno kreirana. Molimo vas da završite plaćanje kako bismo mogli izdati karte.</p>
            <div class='order-info'>
                <h3>Detalji narudžbe:</h3>
                <p><strong>Broj narudžbe:</strong> #{orderId}</p>
                <p><strong>Ukupan iznos:</strong> {totalAmount:F2} BAM</p>
                <p><strong>Status:</strong> Na čekanju</p>
            </div>
            <p>Molimo vas da završite plaćanje kako bismo mogli izdati vaše karte.</p>
        </div>
        <div class='footer'>
            <p>Ovo je automatska poruka, molimo ne odgovarajte na ovaj email.</p>
            <p>&copy; 2024 SApplauz. Sva prava zadržana.</p>
        </div>
    </div>
</body>
</html>";

        return await SendEmailAsync(toEmail, toName, subject, htmlBody);
    }

    public async Task<bool> SendOrderPaidEmailAsync(string toEmail, string toName, int orderId, decimal totalAmount, string paymentIntentId)
    {
        var subject = $"Vaše mjesto je sigurno 🎭";
        var htmlBody = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #6c5ce7; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }}
        .content {{ background-color: #f8f9fa; padding: 30px; border-radius: 0 0 5px 5px; }}
        .order-info {{ background-color: white; padding: 20px; border-radius: 5px; margin: 20px 0; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
        .bold {{ font-weight: bold; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>SApplauz</h1>
        </div>
        <div class='content'>
            <h2>Plaćanje je uspješno evidentirano.</h2>
            <p>Poštovani/na {toName},</p>
            <p>Vaša narudžba na aplikaciji SApplauz je završena i karte su izdane.</p>
            <div class='order-info'>
                <h3>Detalji narudžbe:</h3>
                <p><strong>Broj narudžbe:</strong> #{orderId}</p>
                <p><strong>Ukupan iznos:</strong> {totalAmount:F2} BAM</p>
                <p><strong>Status:</strong> Plaćeno</p>
            </div>
            <p>Vaše karte su odmah dostupne u sekciji <strong>""Moje karte""</strong> u aplikaciji.</p>
            <p class='bold'>SApplauz – nije red da čekaš.</p>
        </div>
        <div class='footer'>
            <p>Ovo je automatska poruka, molimo ne odgovarajte na ovaj email.</p>
            <p>&copy; 2024 SApplauz. Sva prava zadržana.</p>
        </div>
    </div>
</body>
</html>";

        return await SendEmailAsync(toEmail, toName, subject, htmlBody);
    }

    public async Task<bool> SendTicketScannedEmailAsync(string toEmail, string toName, int ticketId, string showTitle)
    {
        var subject = $"Karta skenirana - {showTitle} - SApplauz";
        var htmlBody = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #0984e3; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }}
        .content {{ background-color: #f8f9fa; padding: 30px; border-radius: 0 0 5px 5px; }}
        .ticket-info {{ background-color: white; padding: 20px; border-radius: 5px; margin: 20px 0; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>SApplauz</h1>
        </div>
        <div class='content'>
            <h2>Karta uspješno skenirana</h2>
            <p>Poštovani/na {toName},</p>
            <p>Vaša karta je uspješno skenirana i validirana.</p>
            <div class='ticket-info'>
                <h3>Detalji karte:</h3>
                <p><strong>Broj karte:</strong> #{ticketId}</p>
                <p><strong>Predstava:</strong> {showTitle}</p>
                <p><strong>Status:</strong> Skenirano</p>
            </div>
            <p>Uživajte u predstavi!</p>
        </div>
        <div class='footer'>
            <p>Ovo je automatska poruka, molimo ne odgovarajte na ovaj email.</p>
            <p>&copy; 2024 SApplauz. Sva prava zadržana.</p>
        </div>
    </div>
</body>
</html>";

        return await SendEmailAsync(toEmail, toName, subject, htmlBody);
    }

    public async Task<bool> SendTicketExpiredEmailAsync(string toEmail, string toName, int ticketId, string showTitle, DateTime performanceStartTime)
    {
        var subject = $"Karta istekla - {showTitle} - SApplauz";
        var formattedDate = performanceStartTime.ToString("dd.MM.yyyy HH:mm");
        var htmlBody = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #d63031; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }}
        .content {{ background-color: #f8f9fa; padding: 30px; border-radius: 0 0 5px 5px; }}
        .ticket-info {{ background-color: white; padding: 20px; border-radius: 5px; margin: 20px 0; }}
        .warning-badge {{ background-color: #d63031; color: white; padding: 10px 20px; border-radius: 5px; display: inline-block; margin: 10px 0; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>SApplauz</h1>
        </div>
        <div class='content'>
            <div class='warning-badge'>⚠ Karta istekla</div>
            <h2>Vaša karta je istekla</h2>
            <p>Poštovani/na {toName},</p>
            <p>Nažalost, vaša karta je istekla jer nije skenirana na vrijeme.</p>
            <div class='ticket-info'>
                <h3>Detalji karte:</h3>
                <p><strong>Broj karte:</strong> #{ticketId}</p>
                <p><strong>Predstava:</strong> {showTitle}</p>
                <p><strong>Datum i vrijeme predstave:</strong> {formattedDate}</p>
                <p><strong>Status:</strong> Nevažeća</p>
            </div>
            <p><strong>Razlog:</strong> Karta mora biti skenirana najkasnije 15 minuta nakon početka predstave.</p>
            <p>Ako imate pitanja ili primjedbe, molimo kontaktirajte našu korisničku podršku.</p>
        </div>
        <div class='footer'>
            <p>Ovo je automatska poruka, molimo ne odgovarajte na ovaj email.</p>
            <p>&copy; 2024 SApplauz. Sva prava zadržana.</p>
        </div>
    </div>
</body>
</html>";

        return await SendEmailAsync(toEmail, toName, subject, htmlBody);
    }

    public async Task<bool> SendRefundEmailAsync(string toEmail, string toName, int orderId, decimal refundAmount, string refundId, string reason)
    {
        var subject = $"Refund uspješan - Narudžba #{orderId} - SApplauz";
        var htmlBody = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #fdcb6e; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }}
        .content {{ background-color: #f8f9fa; padding: 30px; border-radius: 0 0 5px 5px; }}
        .refund-info {{ background-color: white; padding: 20px; border-radius: 5px; margin: 20px 0; }}
        .success-badge {{ background-color: #00b894; color: white; padding: 10px 20px; border-radius: 5px; display: inline-block; margin: 10px 0; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>SApplauz</h1>
        </div>
        <div class='content'>
            <div class='success-badge'>✓ Refund uspješan!</div>
            <h2>Refund zahtjev obrađen</h2>
            <p>Poštovani/na {toName},</p>
            <p>Vaša refund zahtjev je uspješno obrađen. Novac će biti vraćen na vašu karticu u roku od 5-10 radnih dana.</p>
            <div class='refund-info'>
                <h3>Detalji refund-a:</h3>
                <p><strong>Broj narudžbe:</strong> #{orderId}</p>
                <p><strong>Refund iznos:</strong> {refundAmount:F2} BAM</p>
                <p><strong>Refund ID:</strong> {refundId}</p>
                <p><strong>Razlog:</strong> {reason}</p>
                <p><strong>Status:</strong> Refundirano</p>
            </div>
            <p>Ako imate pitanja ili primjedbe, molimo kontaktirajte našu korisničku podršku.</p>
        </div>
        <div class='footer'>
            <p>Ovo je automatska poruka, molimo ne odgovarajte na ovaj email.</p>
            <p>&copy; 2024 SApplauz. Sva prava zadržana.</p>
        </div>
    </div>
</body>
</html>";

        return await SendEmailAsync(toEmail, toName, subject, htmlBody);
    }
}


