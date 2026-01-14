namespace SApplauz.Shared.DTOs.Messages;

public class RefundMessage
{
    public int OrderId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string UserEmail { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public decimal RefundAmount { get; set; }
    public string PaymentIntentId { get; set; } = string.Empty;
    public string RefundId { get; set; } = string.Empty;
    public DateTime RefundedAt { get; set; }
    public string Reason { get; set; } = string.Empty;
}
