namespace SApplauz.Shared.DTOs;

public class ReviewFilterRequest
{
    public int? ShowId { get; set; }
    public string? UserId { get; set; }
    public bool? IsVisible { get; set; }
    public int? MinRating { get; set; }
    public int PageNumber { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}






