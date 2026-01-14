namespace SApplauz.Shared.DTOs;

public class PerformanceDto
{
    public int Id { get; set; }
    public int ShowId { get; set; }
    public string ShowTitle { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public decimal Price { get; set; }
    public int AvailableSeats { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public bool IsSoldOut => AvailableSeats == 0;
    public bool IsAlmostSoldOut => AvailableSeats > 0 && AvailableSeats <= 5;
    
    // Status i vizualni identitet
    public string Status { get; set; } = string.Empty;
    public bool IsCurrentlyShowing { get; set; }
    public string StatusColor { get; set; } = string.Empty;
}






