namespace SApplauz.Shared.DTOs;

public class ShowDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int DurationMinutes { get; set; }
    public int InstitutionId { get; set; }
    public string InstitutionName { get; set; } = string.Empty;
    public int GenreId { get; set; }
    public string GenreName { get; set; } = string.Empty;
    public string? ImagePath { get; set; }
    public string? ResolvedImagePath { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public double? AverageRating { get; set; }
    public int ReviewsCount { get; set; }
    public int PerformancesCount { get; set; }
}






