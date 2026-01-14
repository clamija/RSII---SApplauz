namespace SApplauz.Domain.Entities;

public class Institution
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Address { get; set; }
    public int Capacity { get; set; }
    public string? ImagePath { get; set; }
    public string? Website { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    // Navigation properties
    public ICollection<Show> Shows { get; set; } = new List<Show>();
    public ICollection<Order> Orders { get; set; } = new List<Order>();
}






