using AutoMapper;
using SApplauz.Domain.Entities;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Mappings;

public class TicketProfile : Profile
{
    public TicketProfile()
    {
        CreateMap<Ticket, TicketDto>()
            .ForMember(dest => dest.OrderId, opt => opt.MapFrom(src => src.OrderItem.OrderId))
            .ForMember(dest => dest.Status, opt => opt.MapFrom(src => src.Status.ToString()))
            .ForMember(dest => dest.ShowTitle, opt => opt.Ignore())
            .ForMember(dest => dest.PerformanceStartTime, opt => opt.Ignore())
            .ForMember(dest => dest.InstitutionName, opt => opt.Ignore());
    }
}






