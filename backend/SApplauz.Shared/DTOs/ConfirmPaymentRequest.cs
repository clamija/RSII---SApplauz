namespace SApplauz.Shared.DTOs;

public class ConfirmPaymentRequest
{
    public int OrderId { get; set; }
    public string PaymentIntentId { get; set; } = string.Empty;
}



