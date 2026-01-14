namespace SApplauz.Shared.DTOs;

public class InstitutionDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Address { get; set; }
    public int Capacity { get; set; }
    public string? ImagePath { get; set; }
    public string? ResolvedImagePath { get; set; }
    public string? Website { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int ShowsCount { get; set; }
}






