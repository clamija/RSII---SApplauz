namespace SApplauz.Domain.Entities;

public class Show
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int DurationMinutes { get; set; }
    public int InstitutionId { get; set; }
    public int GenreId { get; set; }
    public string? ImagePath { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    // Navigation properties
    public Institution Institution { get; set; } = null!;
    public Genre Genre { get; set; } = null!;
    public ICollection<Performance> Performances { get; set; } = new List<Performance>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
}






