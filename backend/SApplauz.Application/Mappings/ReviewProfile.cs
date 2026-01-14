using AutoMapper;
using SApplauz.Domain.Entities;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Mappings;

public class ReviewProfile : Profile
{
    public ReviewProfile()
    {
        CreateMap<Review, ReviewDto>()
            .ForMember(dest => dest.ShowTitle, opt => opt.Ignore())
            .ForMember(dest => dest.UserName, opt => opt.Ignore());
    }
}






