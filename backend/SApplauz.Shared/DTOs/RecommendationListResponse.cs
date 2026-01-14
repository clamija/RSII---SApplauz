namespace SApplauz.Shared.DTOs;

public class RecommendationListResponse
{
    public List<RecommendationDto> Recommendations { get; set; } = new();
    public int TotalCount { get; set; }
}






