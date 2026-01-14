namespace SApplauz.Domain.Entities;

public class Genre
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties (1:N with Show)
    public ICollection<Show> Shows { get; set; } = new List<Show>();
}






