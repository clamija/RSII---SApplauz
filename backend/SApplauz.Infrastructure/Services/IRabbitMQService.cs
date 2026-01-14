namespace SApplauz.Infrastructure.Services;

public interface IRabbitMQService
{
    void PublishOrderCreated(int orderId, string userId, string userEmail, string userName, decimal totalAmount);
    void PublishOrderPaid(int orderId, string userId, string userEmail, string userName, decimal totalAmount, string paymentIntentId);
    void PublishTicketScanned(int ticketId, string qrCode, int showId, string showTitle);
    void PublishTicketExpired(int ticketId, int orderId, string userId, string userEmail, string userName, int showId, string showTitle, int performanceId, DateTime performanceStartTime);
    void PublishRefund(int orderId, string userId, string userEmail, string userName, decimal refundAmount, string paymentIntentId, string refundId, string reason);
}






