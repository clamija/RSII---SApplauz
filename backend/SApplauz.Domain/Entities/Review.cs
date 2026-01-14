namespace SApplauz.Domain.Entities;

public class Review
{
    public int Id { get; set; }
    public string UserId { get; set; } = string.Empty; // FK to ApplicationUser (Identity)
    public int ShowId { get; set; }
    public int Rating { get; set; } // 1-5
    public string? Comment { get; set; }
    public bool IsVisible { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    // Navigation properties (configured in ApplicationDbContext)
    public Show Show { get; set; } = null!;
}

