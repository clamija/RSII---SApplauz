namespace SApplauz.Domain.Entities;

public class Performance
{
    public int Id { get; set; }
    public int ShowId { get; set; }
    public DateTime StartTime { get; set; }
    public decimal Price { get; set; }
    public int AvailableSeats { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    // Navigation properties
    public Show Show { get; set; } = null!;
    public ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
}






