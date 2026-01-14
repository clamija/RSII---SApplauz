namespace SApplauz.Shared.DTOs;

public class SalesReportDto
{
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public decimal TotalRevenue { get; set; }
    public int TotalOrders { get; set; }
    public int TotalTicketsSold { get; set; }
    public List<SalesByInstitutionDto> SalesByInstitution { get; set; } = new();
    public List<SalesByShowDto> SalesByShow { get; set; } = new();
    public List<DailySalesDto> DailySales { get; set; } = new();
}

public class SalesByInstitutionDto
{
    public int InstitutionId { get; set; }
    public string InstitutionName { get; set; } = string.Empty;
    public decimal Revenue { get; set; }
    public int OrdersCount { get; set; }
    public int TicketsSold { get; set; }
}

public class SalesByShowDto
{
    public int ShowId { get; set; }
    public string ShowTitle { get; set; } = string.Empty;
    public decimal Revenue { get; set; }
    public int OrdersCount { get; set; }
    public int TicketsSold { get; set; }
}

public class DailySalesDto
{
    public DateTime Date { get; set; }
    public decimal Revenue { get; set; }
    public int OrdersCount { get; set; }
    public int TicketsSold { get; set; }
}






