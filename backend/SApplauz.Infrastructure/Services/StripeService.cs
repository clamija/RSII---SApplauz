using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Stripe;
using SApplauz.Infrastructure.Configurations;

namespace SApplauz.Infrastructure.Services;

public class StripeService : IStripeService
{
    private readonly StripeSettings _settings;
    private readonly ILogger<StripeService> _logger;

    public StripeService(IOptions<StripeSettings> settings, ILogger<StripeService> logger)
    {
        _settings = settings.Value;
        _logger = logger;
        
        // Initialize Stripe API key
        StripeConfiguration.ApiKey = _settings.SecretKey;
    }

    public async Task<string> CreatePaymentIntentAsync(int orderId, decimal amount, string currency = "bam")
    {
        try
        {
            var options = new PaymentIntentCreateOptions
            {
                Amount = (long)(amount * 100), // Convert to cents (Stripe uses smallest currency unit)
                Currency = currency.ToLower(),
                Metadata = new Dictionary<string, string>
                {
                    { "orderId", orderId.ToString() }
                },
                AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions
                {
                    Enabled = true,
                }
            };

            var service = new PaymentIntentService();
            var paymentIntent = await service.CreateAsync(options);

            _logger.LogInformation("Created Stripe PaymentIntent {PaymentIntentId} for Order {OrderId} with status {Status}", paymentIntent.Id, orderId, paymentIntent.Status);

            return paymentIntent.ClientSecret ?? paymentIntent.Id;
        }
        catch (StripeException ex)
        {
            _logger.LogError(ex, "Stripe error creating payment intent for Order {OrderId}", orderId);
            throw new InvalidOperationException($"Failed to create payment intent: {ex.Message}", ex);
        }
    }

    public async Task<bool> ConfirmPaymentAsync(string paymentIntentId, string? paymentMethodId = null)
    {
        try
        {
            var service = new PaymentIntentService();
            var paymentIntent = await service.GetAsync(paymentIntentId);

            if (paymentIntent.Status == "succeeded")
            {
                _logger.LogInformation("PaymentIntent {PaymentIntentId} already confirmed", paymentIntentId);
                return true;
            }

            // If payment requires a payment method, it means payment method needs to be attached via frontend
            // In production, this is handled by Stripe Elements on frontend
            // For testing, payment method should be attached before calling confirm endpoint
            if (paymentIntent.Status == "requires_payment_method" && string.IsNullOrEmpty(paymentMethodId) && paymentIntent.PaymentMethodId == null)
            {
                _logger.LogWarning("PaymentIntent {PaymentIntentId} requires payment method but none is provided. Payment method must be attached via Stripe Elements on frontend.", paymentIntentId);
                throw new InvalidOperationException("Payment Intent zahtijeva payment method. Za produkciju i testiranje, koristi Stripe Elements na frontendu da priložiš payment method prije poziva confirm endpoint-a. Stripe ne dozvoljava direktno slanje kartičnih podataka na backend API iz sigurnosnih razloga.");
            }

            if (paymentIntent.Status == "requires_confirmation" || paymentIntent.Status == "requires_payment_method")
            {
                var confirmOptions = new PaymentIntentConfirmOptions();
                
                // If payment method ID is provided or already attached, use it
                if (!string.IsNullOrEmpty(paymentMethodId))
                {
                    confirmOptions.PaymentMethod = paymentMethodId;
                }
                else if (paymentIntent.PaymentMethodId != null)
                {
                    confirmOptions.PaymentMethod = paymentIntent.PaymentMethodId;
                }
                
                var confirmed = await service.ConfirmAsync(paymentIntentId, confirmOptions);
                
                if (confirmed.Status == "succeeded")
                {
                    _logger.LogInformation("PaymentIntent {PaymentIntentId} confirmed successfully", paymentIntentId);
                    return true;
                }
                else
                {
                    _logger.LogWarning("PaymentIntent {PaymentIntentId} confirmation resulted in status {Status}", paymentIntentId, confirmed.Status);
                    return false;
                }
            }

            _logger.LogWarning("PaymentIntent {PaymentIntentId} status is {Status}, cannot confirm", paymentIntentId, paymentIntent.Status);
            return false;
        }
        catch (StripeException ex)
        {
            _logger.LogError(ex, "Stripe error confirming payment {PaymentIntentId}: {Message}", paymentIntentId, ex.Message);
            throw new InvalidOperationException($"Greška pri potvrdi plaćanja: {ex.Message}", ex);
        }
    }

    public async Task<bool> RefundPaymentAsync(string paymentIntentId, decimal? amount = null)
    {
        // Seeder/test podaci koriste "pi_seed_*" koji ne postoji na Stripe-u.
        // Za potrebe testiranja refund flow-a, tretiramo to kao uspješan "mock" refund.
        if (!string.IsNullOrWhiteSpace(paymentIntentId) &&
            paymentIntentId.StartsWith("pi_seed_", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogInformation("Mock refund for seed PaymentIntentId {PaymentIntentId}", paymentIntentId);
            return true;
        }

        try
        {
            var service = new RefundService();
            var options = new RefundCreateOptions
            {
                PaymentIntent = paymentIntentId,
            };

            if (amount.HasValue)
            {
                options.Amount = (long)(amount.Value * 100); // Convert to cents
            }

            var refund = await service.CreateAsync(options);

            if (refund.Status == "succeeded" || refund.Status == "pending")
            {
                _logger.LogInformation("Refund created for PaymentIntent {PaymentIntentId}, RefundId: {RefundId}", paymentIntentId, refund.Id);
                return true;
            }

            _logger.LogWarning("Refund for PaymentIntent {PaymentIntentId} has status {Status}", paymentIntentId, refund.Status);
            return false;
        }
        catch (StripeException ex)
        {
            _logger.LogError(ex, "Stripe error creating refund for {PaymentIntentId}", paymentIntentId);
            return false;
        }
    }
}



