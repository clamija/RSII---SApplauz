using AutoMapper;
using SApplauz.Domain.Entities;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Mappings;

public class ShowProfile : Profile
{
    public ShowProfile()
    {
        CreateMap<Show, ShowDto>()
            .ForMember(dest => dest.InstitutionName, opt => opt.Ignore())
            .ForMember(dest => dest.GenreId, opt => opt.MapFrom(src => src.GenreId))
            .ForMember(dest => dest.GenreName, opt => opt.Ignore())
            .ForMember(dest => dest.AverageRating, opt => opt.Ignore())
            .ForMember(dest => dest.ReviewsCount, opt => opt.Ignore())
            .ForMember(dest => dest.PerformancesCount, opt => opt.Ignore());
        
        CreateMap<CreateShowRequest, Show>()
            .ForMember(dest => dest.Id, opt => opt.Ignore())
            .ForMember(dest => dest.CreatedAt, opt => opt.MapFrom(src => DateTime.UtcNow))
            .ForMember(dest => dest.UpdatedAt, opt => opt.Ignore())
            .ForMember(dest => dest.Institution, opt => opt.Ignore())
            .ForMember(dest => dest.Genre, opt => opt.Ignore())
            .ForMember(dest => dest.Performances, opt => opt.Ignore())
            .ForMember(dest => dest.Reviews, opt => opt.Ignore());
        
        CreateMap<UpdateShowRequest, Show>()
            .ForMember(dest => dest.Id, opt => opt.Ignore())
            .ForMember(dest => dest.CreatedAt, opt => opt.Ignore())
            .ForMember(dest => dest.UpdatedAt, opt => opt.MapFrom(src => DateTime.UtcNow))
            .ForMember(dest => dest.Institution, opt => opt.Ignore())
            .ForMember(dest => dest.Genre, opt => opt.Ignore())
            .ForMember(dest => dest.Performances, opt => opt.Ignore())
            .ForMember(dest => dest.Reviews, opt => opt.Ignore());
    }
}






