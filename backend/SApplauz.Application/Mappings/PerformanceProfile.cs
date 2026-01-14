using AutoMapper;
using SApplauz.Domain.Entities;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Mappings;

public class PerformanceProfile : Profile
{
    public PerformanceProfile()
    {
        CreateMap<Performance, PerformanceDto>()
            .ForMember(dest => dest.ShowTitle, opt => opt.Ignore())
            .ForMember(dest => dest.IsSoldOut, opt => opt.MapFrom(src => src.AvailableSeats == 0))
            .ForMember(dest => dest.IsAlmostSoldOut, opt => opt.MapFrom(src => src.AvailableSeats > 0 && src.AvailableSeats <= 5));
        
        CreateMap<CreatePerformanceRequest, Performance>()
            .ForMember(dest => dest.Id, opt => opt.Ignore())
            .ForMember(dest => dest.CreatedAt, opt => opt.MapFrom(src => DateTime.UtcNow))
            .ForMember(dest => dest.UpdatedAt, opt => opt.Ignore())
            .ForMember(dest => dest.AvailableSeats, opt => opt.Ignore())
            .ForMember(dest => dest.Show, opt => opt.Ignore())
            .ForMember(dest => dest.OrderItems, opt => opt.Ignore());
        
        CreateMap<UpdatePerformanceRequest, Performance>()
            .ForMember(dest => dest.Id, opt => opt.Ignore())
            .ForMember(dest => dest.CreatedAt, opt => opt.Ignore())
            .ForMember(dest => dest.UpdatedAt, opt => opt.MapFrom(src => DateTime.UtcNow))
            .ForMember(dest => dest.AvailableSeats, opt => opt.Ignore())
            .ForMember(dest => dest.Show, opt => opt.Ignore())
            .ForMember(dest => dest.OrderItems, opt => opt.Ignore());
    }
}






