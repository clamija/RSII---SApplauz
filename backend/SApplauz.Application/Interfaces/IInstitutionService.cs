using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface IInstitutionService
{
    Task<InstitutionDto?> GetInstitutionByIdAsync(int id);
    Task<List<InstitutionDto>> GetAllInstitutionsAsync(bool? isActive = null);
    Task<InstitutionDto> CreateInstitutionAsync(CreateInstitutionRequest request);
    Task<InstitutionDto> UpdateInstitutionAsync(int id, UpdateInstitutionRequest request);
    Task DeleteInstitutionAsync(int id);
}






