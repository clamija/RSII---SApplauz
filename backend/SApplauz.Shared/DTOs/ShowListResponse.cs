namespace SApplauz.Shared.DTOs;

public class ShowListResponse
{
    public List<ShowDto> Shows { get; set; } = new();
    public int TotalCount { get; set; }
    public int PageNumber { get; set; }
    public int PageSize { get; set; }
}






