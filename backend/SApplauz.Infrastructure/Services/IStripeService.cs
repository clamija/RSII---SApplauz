namespace SApplauz.Infrastructure.Services;

public interface IStripeService
{
    Task<string> CreatePaymentIntentAsync(int orderId, decimal amount, string currency = "bam");
    Task<bool> ConfirmPaymentAsync(string paymentIntentId, string? paymentMethodId = null);
    Task<bool> RefundPaymentAsync(string paymentIntentId, decimal? amount = null);
}



