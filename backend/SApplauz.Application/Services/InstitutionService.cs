using AutoMapper;
using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Services;

public class InstitutionService : IInstitutionService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IMapper _mapper;

    public InstitutionService(ApplicationDbContext dbContext, IMapper mapper)
    {
        _dbContext = dbContext;
        _mapper = mapper;
    }

    public async Task<InstitutionDto?> GetInstitutionByIdAsync(int id)
    {
        var institution = await _dbContext.Institutions
            .Include(i => i.Shows)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (institution == null)
        {
            return null;
        }

        var dto = _mapper.Map<InstitutionDto>(institution);
        dto.ShowsCount = institution.Shows.Count;
        dto.ResolvedImagePath = institution.ImagePath ?? "/images/default.png";
        return dto;
    }

    public async Task<List<InstitutionDto>> GetAllInstitutionsAsync(bool? isActive = null)
    {
        var query = _dbContext.Institutions.AsQueryable();

        if (isActive.HasValue)
        {
            query = query.Where(i => i.IsActive == isActive.Value);
        }

        var institutions = await query
            .Include(i => i.Shows)
            .OrderBy(i => i.Name)
            .ToListAsync();

        return institutions.Select(i =>
        {
            var dto = _mapper.Map<InstitutionDto>(i);
            dto.ShowsCount = i.Shows.Count;
            dto.ResolvedImagePath = i.ImagePath ?? "/images/default.png";
            return dto;
        }).ToList();
    }

    public async Task<InstitutionDto> CreateInstitutionAsync(CreateInstitutionRequest request)
    {
        var institution = _mapper.Map<Institution>(request);
        institution.CreatedAt = DateTime.UtcNow;

        _dbContext.Institutions.Add(institution);
        await _dbContext.SaveChangesAsync();

        var dto = _mapper.Map<InstitutionDto>(institution);
        dto.ShowsCount = 0;
        dto.ResolvedImagePath = institution.ImagePath ?? "/images/default.png";
        return dto;
    }

    public async Task<InstitutionDto> UpdateInstitutionAsync(int id, UpdateInstitutionRequest request)
    {
        var institution = await _dbContext.Institutions.FindAsync(id);
        if (institution == null)
        {
            throw new KeyNotFoundException($"Institution with id {id} not found.");
        }

        institution.Name = request.Name;
        institution.Description = request.Description;
        institution.Address = request.Address;
        institution.Capacity = request.Capacity;
        institution.ImagePath = request.ImagePath;
        institution.Website = request.Website;
        institution.IsActive = request.IsActive;
        institution.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync();

        await _dbContext.Entry(institution)
            .Collection(i => i.Shows)
            .LoadAsync();

        var dto = _mapper.Map<InstitutionDto>(institution);
        dto.ShowsCount = institution.Shows.Count;
        dto.ResolvedImagePath = institution.ImagePath ?? "/images/default.png";
        return dto;
    }

    public async Task DeleteInstitutionAsync(int id)
    {
        var institution = await _dbContext.Institutions.FindAsync(id);
        if (institution == null)
        {
            throw new KeyNotFoundException($"Institution with id {id} not found.");
        }

        // Check if institution has shows
        var showsCount = await _dbContext.Shows.CountAsync(s => s.InstitutionId == id);
        if (showsCount > 0)
        {
            throw new InvalidOperationException($"Ne možete obrisati instituciju jer se koristi u {showsCount} {(showsCount == 1 ? "predstavi" : "predstava")}.");
        }

        _dbContext.Institutions.Remove(institution);
        await _dbContext.SaveChangesAsync();
    }
}






