namespace SApplauz.Shared.DTOs;

public class ValidateTicketResponse
{
    public bool IsValid { get; set; }
    public string Message { get; set; } = string.Empty;
    public TicketDto? Ticket { get; set; }
}






