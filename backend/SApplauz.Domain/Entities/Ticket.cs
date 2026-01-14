namespace SApplauz.Domain.Entities;

public class Ticket
{
    public int Id { get; set; }
    public int OrderItemId { get; set; }
    public string QRCode { get; set; } = string.Empty; // Unique QR code
    public TicketStatus Status { get; set; } = TicketStatus.NotScanned;
    public DateTime? ScannedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public OrderItem OrderItem { get; set; } = null!;
}

public enum TicketStatus
{
    NotScanned = 0,
    Scanned = 1,
    Invalid = 2,
    Refunded = 3
}






