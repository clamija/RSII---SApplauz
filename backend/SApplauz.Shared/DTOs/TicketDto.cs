namespace SApplauz.Shared.DTOs;

public class TicketDto
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public int OrderItemId { get; set; }
    public string QRCode { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime? ScannedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    // Additional info for display
    public string UserFullName { get; set; } = string.Empty;
    public int InstitutionId { get; set; }
    public string ShowTitle { get; set; } = string.Empty;
    public DateTime PerformanceStartTime { get; set; }
    public string InstitutionName { get; set; } = string.Empty;
}






