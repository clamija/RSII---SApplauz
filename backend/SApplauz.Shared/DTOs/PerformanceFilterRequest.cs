namespace SApplauz.Shared.DTOs;

public class PerformanceFilterRequest
{
    public int? ShowId { get; set; }
    public int? InstitutionId { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public bool? AvailableOnly { get; set; }
    public int PageNumber { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}






