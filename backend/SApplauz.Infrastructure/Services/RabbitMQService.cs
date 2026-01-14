using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using SApplauz.Infrastructure.Configurations;
using SApplauz.Shared.DTOs.Messages;

namespace SApplauz.Infrastructure.Services;

public class RabbitMQService : IRabbitMQService, IDisposable
{
    private readonly RabbitMQSettings _settings;
    private readonly ILogger<RabbitMQService> _logger;
    private IConnection? _connection;
    private IModel? _channel;

    public RabbitMQService(IOptions<RabbitMQSettings> settings, ILogger<RabbitMQService> logger)
    {
        _settings = settings.Value;
        _logger = logger;
        InitializeConnection();
    }

    private void InitializeConnection()
    {
        try
        {
            var factory = new ConnectionFactory
            {
                HostName = _settings.Host,
                Port = _settings.Port,
                UserName = _settings.Username,
                Password = _settings.Password,
                VirtualHost = _settings.VirtualHost
            };

            _connection = factory.CreateConnection();
            _channel = _connection.CreateModel();

            // Declare queues
            _channel.QueueDeclare(queue: "order_created", durable: true, exclusive: false, autoDelete: false);
            _channel.QueueDeclare(queue: "order_paid", durable: true, exclusive: false, autoDelete: false);
            _channel.QueueDeclare(queue: "ticket_scanned", durable: true, exclusive: false, autoDelete: false);
            _channel.QueueDeclare(queue: "ticket_expired", durable: true, exclusive: false, autoDelete: false);
            _channel.QueueDeclare(queue: "refund", durable: true, exclusive: false, autoDelete: false);

            _logger.LogInformation("RabbitMQ connection established.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize RabbitMQ connection.");
            throw;
        }
    }

    public void PublishOrderCreated(int orderId, string userId, string userEmail, string userName, decimal totalAmount)
    {
        try
        {
            var message = new OrderCreatedMessage
            {
                OrderId = orderId,
                UserId = userId,
                UserEmail = userEmail,
                UserName = userName,
                TotalAmount = totalAmount,
                CreatedAt = DateTime.UtcNow
            };

            PublishMessage("order_created", message);
            _logger.LogInformation("Published OrderCreated message for OrderId: {OrderId}", orderId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish OrderCreated message for OrderId: {OrderId}", orderId);
        }
    }

    public void PublishOrderPaid(int orderId, string userId, string userEmail, string userName, decimal totalAmount, string paymentIntentId)
    {
        try
        {
            var message = new OrderPaidMessage
            {
                OrderId = orderId,
                UserId = userId,
                UserEmail = userEmail,
                UserName = userName,
                TotalAmount = totalAmount,
                PaymentIntentId = paymentIntentId,
                PaidAt = DateTime.UtcNow
            };

            PublishMessage("order_paid", message);
            _logger.LogInformation("Published OrderPaid message for OrderId: {OrderId}", orderId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish OrderPaid message for OrderId: {OrderId}", orderId);
        }
    }

    public void PublishTicketScanned(int ticketId, string qrCode, int showId, string showTitle)
    {
        try
        {
            var message = new TicketScannedMessage
            {
                TicketId = ticketId,
                QRCode = qrCode,
                ShowId = showId,
                ShowTitle = showTitle,
                ScannedAt = DateTime.UtcNow
            };

            PublishMessage("ticket_scanned", message);
            _logger.LogInformation("Published TicketScanned message for TicketId: {TicketId}", ticketId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish TicketScanned message for TicketId: {TicketId}", ticketId);
        }
    }

    public void PublishTicketExpired(int ticketId, int orderId, string userId, string userEmail, string userName, int showId, string showTitle, int performanceId, DateTime performanceStartTime)
    {
        try
        {
            var message = new TicketExpiredMessage
            {
                TicketId = ticketId,
                OrderId = orderId,
                UserId = userId,
                UserEmail = userEmail,
                UserName = userName,
                ShowId = showId,
                ShowTitle = showTitle,
                PerformanceId = performanceId,
                PerformanceStartTime = performanceStartTime,
                ExpiredAt = DateTime.UtcNow
            };

            PublishMessage("ticket_expired", message);
            _logger.LogInformation("Published TicketExpired message for TicketId: {TicketId}", ticketId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish TicketExpired message for TicketId: {TicketId}", ticketId);
        }
    }

    public void PublishRefund(int orderId, string userId, string userEmail, string userName, decimal refundAmount, string paymentIntentId, string refundId, string reason)
    {
        try
        {
            var message = new RefundMessage
            {
                OrderId = orderId,
                UserId = userId,
                UserEmail = userEmail,
                UserName = userName,
                RefundAmount = refundAmount,
                PaymentIntentId = paymentIntentId,
                RefundId = refundId,
                RefundedAt = DateTime.UtcNow,
                Reason = reason
            };

            PublishMessage("refund", message);
            _logger.LogInformation("Published Refund message for OrderId: {OrderId}", orderId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish Refund message for OrderId: {OrderId}", orderId);
        }
    }

    private void PublishMessage<T>(string queueName, T message)
    {
        if (_channel == null || _connection == null || !_connection.IsOpen)
        {
            InitializeConnection();
        }

        var json = JsonSerializer.Serialize(message);
        var body = Encoding.UTF8.GetBytes(json);

        var properties = _channel!.CreateBasicProperties();
        properties.Persistent = true;

        _channel.BasicPublish(
            exchange: "",
            routingKey: queueName,
            basicProperties: properties,
            body: body);
    }

    public void Dispose()
    {
        _channel?.Close();
        _channel?.Dispose();
        _connection?.Close();
        _connection?.Dispose();
    }
}

