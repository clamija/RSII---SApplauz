namespace SApplauz.Shared.DTOs;

public class ReportFilterRequest
{
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public int? InstitutionId { get; set; }
    public int? ShowId { get; set; }
}






