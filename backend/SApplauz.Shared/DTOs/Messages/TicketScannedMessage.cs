namespace SApplauz.Shared.DTOs.Messages;

public class TicketScannedMessage
{
    public int TicketId { get; set; }
    public string QRCode { get; set; } = string.Empty;
    public int ShowId { get; set; }
    public string ShowTitle { get; set; } = string.Empty;
    public DateTime ScannedAt { get; set; }
}






