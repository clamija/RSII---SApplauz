namespace SApplauz.Shared.DTOs;

public class OrderItemDto
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public int PerformanceId { get; set; }
    public string PerformanceShowTitle { get; set; } = string.Empty;
    public DateTime PerformanceStartTime { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal Subtotal => Quantity * UnitPrice;
    public List<TicketDto> Tickets { get; set; } = new();
}






