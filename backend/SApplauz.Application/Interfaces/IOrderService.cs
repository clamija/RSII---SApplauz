using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface IOrderService
{
    Task<OrderDto?> GetOrderByIdAsync(int id);
    Task<OrderListResponse> GetUserOrdersAsync(string userId, int pageNumber, int pageSize);
    Task<OrderListResponse> GetInstitutionOrdersAsync(int? institutionId, int pageNumber, int pageSize, string? status = null, DateTime? startDate = null, DateTime? endDate = null);
    Task<OrderDto> CreateOrderAsync(string userId, CreateOrderRequest request);
    Task<OrderDto> CancelOrderAsync(int id, string userId);
    Task<OrderDto> RefundOrderAsync(int id, string userId, string reason = "Korisnički zahtjev");
    Task<List<TicketDto>> GetOrderTicketsAsync(int orderId, string userId);
    Task<CreatePaymentIntentResponse> CreatePaymentIntentAsync(int orderId, string userId);
    Task<OrderDto> ProcessPaymentAsync(int orderId, string paymentIntentId, string userId);
}




