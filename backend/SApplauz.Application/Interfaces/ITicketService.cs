using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface ITicketService
{
    Task<ValidateTicketResponse> ValidateTicketAsync(string qrCode, int? institutionId = null);
    Task<List<TicketDto>> GetUserTicketsAsync(string userId);
    Task<TicketDto?> GetTicketByQRCodeAsync(string qrCode);
    Task<List<TicketDto>> GetPaidTicketsAsync(int? institutionId = null, string? status = null);
}






