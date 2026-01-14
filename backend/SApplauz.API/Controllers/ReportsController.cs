using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ReportsController : ControllerBase
{
    private readonly IReportService _reportService;
    private readonly ILogger<ReportsController> _logger;

    public ReportsController(IReportService reportService, ILogger<ReportsController> logger)
    {
        _reportService = reportService;
        _logger = logger;
    }

    [HttpGet("sales")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<SalesReportDto>> GetSalesReport([FromQuery] ReportFilterRequest filter)
    {
        try
        {
            var report = await _reportService.GetSalesReportAsync(filter);
            return Ok(report);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting sales report");
            return StatusCode(500, new { message = "An error occurred while retrieving sales report." });
        }
    }

    [HttpGet("popularity")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<PopularityReportDto>> GetPopularityReport([FromQuery] ReportFilterRequest filter)
    {
        try
        {
            var report = await _reportService.GetPopularityReportAsync(filter);
            return Ok(report);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting popularity report");
            return StatusCode(500, new { message = "An error occurred while retrieving popularity report." });
        }
    }
}





