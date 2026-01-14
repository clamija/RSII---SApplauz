namespace SApplauz.Shared.DTOs.Messages;

public class TicketExpiredMessage
{
    public int TicketId { get; set; }
    public int OrderId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string UserEmail { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public int ShowId { get; set; }
    public string ShowTitle { get; set; } = string.Empty;
    public int PerformanceId { get; set; }
    public DateTime PerformanceStartTime { get; set; }
    public DateTime ExpiredAt { get; set; }
}
