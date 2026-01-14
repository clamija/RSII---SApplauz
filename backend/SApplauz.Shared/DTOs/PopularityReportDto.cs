namespace SApplauz.Shared.DTOs;

public class PopularityReportDto
{
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public List<ShowPopularityDto> MostPopularShows { get; set; } = new();
    public List<GenrePopularityDto> MostPopularGenres { get; set; } = new();
    public List<InstitutionPopularityDto> MostPopularInstitutions { get; set; } = new();
}

public class ShowPopularityDto
{
    public int ShowId { get; set; }
    public string ShowTitle { get; set; } = string.Empty;
    public int TicketsSold { get; set; }
    public int ReviewsCount { get; set; }
    public double? AverageRating { get; set; }
    public decimal Revenue { get; set; }
}

public class GenrePopularityDto
{
    public int GenreId { get; set; }
    public string GenreName { get; set; } = string.Empty;
    public int ShowsCount { get; set; }
    public int TicketsSold { get; set; }
    public decimal Revenue { get; set; }
}

public class InstitutionPopularityDto
{
    public int InstitutionId { get; set; }
    public string InstitutionName { get; set; } = string.Empty;
    public int ShowsCount { get; set; }
    public int TicketsSold { get; set; }
    public decimal Revenue { get; set; }
}






