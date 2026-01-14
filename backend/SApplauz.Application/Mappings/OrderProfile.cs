using AutoMapper;
using SApplauz.Domain.Entities;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Mappings;

public class OrderProfile : Profile
{
    public OrderProfile()
    {
        CreateMap<Order, OrderDto>()
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status.ToString()))
            // SQL Server (datetime2) ne čuva DateTimeKind; forsiramo UTC u DTO da JSON dobije 'Z'
            // i klijent može korektno prikazati lokalno vrijeme.
            .ForMember(dest => dest.CreatedAt, opt => opt.MapFrom(src => DateTime.SpecifyKind(src.CreatedAt, DateTimeKind.Utc)))
            .ForMember(dest => dest.UpdatedAt, opt => opt.MapFrom(src => src.UpdatedAt.HasValue ? DateTime.SpecifyKind(src.UpdatedAt.Value, DateTimeKind.Utc) : (DateTime?)null))
            .ForMember(dest => dest.InstitutionName, opt => opt.Ignore())
            .ForMember(dest => dest.UserName, opt => opt.Ignore())
            .ForMember(dest => dest.OrderItems, opt => opt.Ignore());
        
        CreateMap<OrderItem, OrderItemDto>()
            .ForMember(dest => dest.PerformanceShowTitle, opt => opt.Ignore())
            .ForMember(dest => dest.PerformanceStartTime, opt => opt.Ignore())
            .ForMember(dest => dest.Subtotal, opt => opt.MapFrom(src => src.Quantity * src.UnitPrice))
            .ForMember(dest => dest.Tickets, opt => opt.Ignore());
    }
}






