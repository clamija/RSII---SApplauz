namespace SApplauz.Domain.Entities;

public class RecommendationProfile
{
    public int Id { get; set; }
    public string UserId { get; set; } = string.Empty; // FK to ApplicationUser (Identity)
    public string? PreferredGenresJson { get; set; } // JSON string for genre preferences
    public DateTime LastUpdated { get; set; } = DateTime.UtcNow;

    // Navigation properties (configured in ApplicationDbContext)
}

