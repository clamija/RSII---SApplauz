namespace SApplauz.Shared.DTOs;

public class ShowFilterRequest
{
    public int? InstitutionId { get; set; }
    public int? GenreId { get; set; }
    public string? SearchTerm { get; set; }
    public bool? IsActive { get; set; }
    public int PageNumber { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}






