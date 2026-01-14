namespace SApplauz.Infrastructure.Services;

public interface IEmailService
{
    Task<bool> SendEmailAsync(string toEmail, string toName, string subject, string htmlBody, string? plainTextBody = null);
    Task<bool> SendOrderCreatedEmailAsync(string toEmail, string toName, int orderId, decimal totalAmount);
    Task<bool> SendOrderPaidEmailAsync(string toEmail, string toName, int orderId, decimal totalAmount, string paymentIntentId);
    Task<bool> SendTicketScannedEmailAsync(string toEmail, string toName, int ticketId, string showTitle);
    Task<bool> SendTicketExpiredEmailAsync(string toEmail, string toName, int ticketId, string showTitle, DateTime performanceStartTime);
    Task<bool> SendRefundEmailAsync(string toEmail, string toName, int orderId, decimal refundAmount, string refundId, string reason);
}


