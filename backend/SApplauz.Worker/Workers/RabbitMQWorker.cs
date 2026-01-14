using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using SApplauz.Infrastructure.Configurations;
using SApplauz.Infrastructure.Identity;
using SApplauz.Infrastructure.Services;
using SApplauz.Shared.DTOs.Messages;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace SApplauz.Worker.Workers;

public class RabbitMQWorker : BackgroundService
{
    private readonly ILogger<RabbitMQWorker> _logger;
    private readonly RabbitMQSettings _settings;
    private readonly IServiceProvider _serviceProvider;
    private IConnection? _connection;
    private IModel? _channel;

    public RabbitMQWorker(
        ILogger<RabbitMQWorker> logger,
        IOptions<RabbitMQSettings> settings,
        IServiceProvider serviceProvider)
    {
        _logger = logger;
        _settings = settings.Value;
        _serviceProvider = serviceProvider;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await InitializeConnectionAsync(stoppingToken);

        if (_connection == null || _channel == null)
        {
            _logger.LogError("Failed to initialize RabbitMQ connection. Worker will not process messages.");
            return;
        }

        // Set up consumers for each queue
        SetupConsumer("order_created", HandleOrderCreated, stoppingToken);
        SetupConsumer("order_paid", HandleOrderPaid, stoppingToken);
        SetupConsumer("ticket_scanned", HandleTicketScanned, stoppingToken);
        SetupConsumer("ticket_expired", HandleTicketExpired, stoppingToken);
        SetupConsumer("refund", HandleRefund, stoppingToken);

        _logger.LogInformation("RabbitMQ Worker started. Waiting for messages...");

        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(1000, stoppingToken);
        }
    }

    private async Task InitializeConnectionAsync(CancellationToken stoppingToken)
    {
        var retryCount = 0;
        const int maxRetries = 5;

        while (retryCount < maxRetries && !stoppingToken.IsCancellationRequested)
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
                return;
            }
            catch (Exception ex)
            {
                retryCount++;
                _logger.LogWarning(ex, "Failed to connect to RabbitMQ. Retry {RetryCount}/{MaxRetries}", retryCount, maxRetries);
                
                if (retryCount < maxRetries)
                {
                    await Task.Delay(5000, stoppingToken);
                }
            }
        }

        _logger.LogError("Failed to establish RabbitMQ connection after {MaxRetries} attempts.", maxRetries);
    }

    private void SetupConsumer(string queueName, Func<string, Task> messageHandler, CancellationToken stoppingToken)
    {
        if (_channel == null) return;

        var consumer = new EventingBasicConsumer(_channel);
        consumer.Received += async (model, ea) =>
        {
            var body = ea.Body.ToArray();
            var message = Encoding.UTF8.GetString(body);

            try
            {
                await messageHandler(message);
                _channel.BasicAck(deliveryTag: ea.DeliveryTag, multiple: false);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing message from queue {QueueName}", queueName);
                _channel.BasicNack(deliveryTag: ea.DeliveryTag, multiple: false, requeue: true);
            }
        };

        _channel.BasicConsume(queue: queueName, autoAck: false, consumer: consumer);
        _logger.LogInformation("Consumer set up for queue: {QueueName}", queueName);
    }

    private async Task HandleOrderCreated(string message)
    {
        try
        {
            var orderMessage = JsonSerializer.Deserialize<OrderCreatedMessage>(message);
            if (orderMessage == null)
            {
                _logger.LogWarning("Failed to deserialize OrderCreatedMessage");
                return;
            }

            _logger.LogInformation(
                "Processing OrderCreated: OrderId={OrderId}, UserId={UserId}, Amount={Amount}",
                orderMessage.OrderId,
                orderMessage.UserId,
                orderMessage.TotalAmount
            );

            // Send email notification
            using (var scope = _serviceProvider.CreateScope())
            {
                var emailService = scope.ServiceProvider.GetRequiredService<IEmailService>();
                var emailSent = await emailService.SendOrderCreatedEmailAsync(
                    orderMessage.UserEmail,
                    orderMessage.UserName,
                    orderMessage.OrderId,
                    orderMessage.TotalAmount
                );

                if (emailSent)
                {
                    _logger.LogInformation("OrderCreated email sent successfully to {UserEmail}", orderMessage.UserEmail);
                }
                else
                {
                    _logger.LogWarning("Failed to send OrderCreated email to {UserEmail}", orderMessage.UserEmail);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling OrderCreated message");
            throw;
        }
    }

    private async Task HandleOrderPaid(string message)
    {
        try
        {
            var orderMessage = JsonSerializer.Deserialize<OrderPaidMessage>(message);
            if (orderMessage == null)
            {
                _logger.LogWarning("Failed to deserialize OrderPaidMessage");
                return;
            }

            _logger.LogInformation(
                "Processing OrderPaid: OrderId={OrderId}, UserId={UserId}, Amount={Amount}, PaymentIntentId={PaymentIntentId}",
                orderMessage.OrderId,
                orderMessage.UserId,
                orderMessage.TotalAmount,
                orderMessage.PaymentIntentId
            );

            // Send confirmation email
            using (var scope = _serviceProvider.CreateScope())
            {
                var emailService = scope.ServiceProvider.GetRequiredService<IEmailService>();
                var emailSent = await emailService.SendOrderPaidEmailAsync(
                    orderMessage.UserEmail,
                    orderMessage.UserName,
                    orderMessage.OrderId,
                    orderMessage.TotalAmount,
                    orderMessage.PaymentIntentId
                );

                if (emailSent)
                {
                    _logger.LogInformation("OrderPaid email sent successfully to {UserEmail}", orderMessage.UserEmail);
                }
                else
                {
                    _logger.LogWarning("Failed to send OrderPaid email to {UserEmail}", orderMessage.UserEmail);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling OrderPaid message");
            throw;
        }
    }

    private async Task HandleTicketScanned(string message)
    {
        try
        {
            var ticketMessage = JsonSerializer.Deserialize<TicketScannedMessage>(message);
            if (ticketMessage == null)
            {
                _logger.LogWarning("Failed to deserialize TicketScannedMessage");
                return;
            }

            _logger.LogInformation(
                "Processing TicketScanned: TicketId={TicketId}, ShowId={ShowId}, ShowTitle={ShowTitle}",
                ticketMessage.TicketId,
                ticketMessage.ShowId,
                ticketMessage.ShowTitle
            );

            // Send email notification (if user email is available)
            // Note: TicketScannedMessage might need user email - for now we'll skip email for this event
            // as it's typically an internal event for analytics
            // If you want to send email to ticket owner, you'd need to fetch user email from database
            _logger.LogInformation("Ticket scanned event processed. Email notification skipped (internal event).");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling TicketScanned message");
            throw;
        }
    }

    private async Task HandleTicketExpired(string message)
    {
        try
        {
            var ticketMessage = JsonSerializer.Deserialize<TicketExpiredMessage>(message);
            if (ticketMessage == null)
            {
                _logger.LogWarning("Failed to deserialize TicketExpiredMessage");
                return;
            }

            _logger.LogInformation(
                "Processing TicketExpired: TicketId={TicketId}, OrderId={OrderId}, UserId={UserId}, ShowTitle={ShowTitle}",
                ticketMessage.TicketId,
                ticketMessage.OrderId,
                ticketMessage.UserId,
                ticketMessage.ShowTitle
            );

            // Send email notification
            using (var scope = _serviceProvider.CreateScope())
            {
                var emailService = scope.ServiceProvider.GetRequiredService<IEmailService>();
                var emailSent = await emailService.SendTicketExpiredEmailAsync(
                    ticketMessage.UserEmail,
                    ticketMessage.UserName,
                    ticketMessage.TicketId,
                    ticketMessage.ShowTitle,
                    ticketMessage.PerformanceStartTime
                );

                if (emailSent)
                {
                    _logger.LogInformation("TicketExpired email sent successfully to {UserEmail}", ticketMessage.UserEmail);
                }
                else
                {
                    _logger.LogWarning("Failed to send TicketExpired email to {UserEmail}", ticketMessage.UserEmail);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling TicketExpired message");
            throw;
        }
    }

    private async Task HandleRefund(string message)
    {
        try
        {
            var refundMessage = JsonSerializer.Deserialize<RefundMessage>(message);
            if (refundMessage == null)
            {
                _logger.LogWarning("Failed to deserialize RefundMessage");
                return;
            }

            _logger.LogInformation(
                "Processing Refund: OrderId={OrderId}, UserId={UserId}, RefundAmount={RefundAmount}, RefundId={RefundId}",
                refundMessage.OrderId,
                refundMessage.UserId,
                refundMessage.RefundAmount,
                refundMessage.RefundId
            );

            // Send email notification
            using (var scope = _serviceProvider.CreateScope())
            {
                var emailService = scope.ServiceProvider.GetRequiredService<IEmailService>();
                var emailSent = await emailService.SendRefundEmailAsync(
                    refundMessage.UserEmail,
                    refundMessage.UserName,
                    refundMessage.OrderId,
                    refundMessage.RefundAmount,
                    refundMessage.RefundId,
                    refundMessage.Reason
                );

                if (emailSent)
                {
                    _logger.LogInformation("Refund email sent successfully to {UserEmail}", refundMessage.UserEmail);
                }
                else
                {
                    _logger.LogWarning("Failed to send Refund email to {UserEmail}", refundMessage.UserEmail);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling Refund message");
            throw;
        }
    }

    public override void Dispose()
    {
        _channel?.Close();
        _channel?.Dispose();
        _connection?.Close();
        _connection?.Dispose();
        base.Dispose();
    }
}





