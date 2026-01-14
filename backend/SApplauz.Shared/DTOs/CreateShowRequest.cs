namespace SApplauz.Shared.DTOs;

public class CreateShowRequest
{
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int DurationMinutes { get; set; }
    public int InstitutionId { get; set; }
    public int GenreId { get; set; }
    public string? ImagePath { get; set; }
    public bool IsActive { get; set; } = true;
}






