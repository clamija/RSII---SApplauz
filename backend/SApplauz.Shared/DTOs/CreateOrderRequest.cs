namespace SApplauz.Shared.DTOs;

public class CreateOrderRequest
{
    public int InstitutionId { get; set; }
    public List<OrderItemRequest> OrderItems { get; set; } = new();
}

public class OrderItemRequest
{
    public int PerformanceId { get; set; }
    public int Quantity { get; set; }
}






