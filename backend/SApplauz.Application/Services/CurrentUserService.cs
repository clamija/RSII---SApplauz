using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Infrastructure.Identity;

namespace SApplauz.Application.Services;

public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ApplicationDbContext _dbContext;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor, ApplicationDbContext dbContext)
    {
        _httpContextAccessor = httpContextAccessor;
        _dbContext = dbContext;
    }

    public string? UserId => _httpContextAccessor.HttpContext?.User?.FindFirstValue(ClaimTypes.NameIdentifier);

    public string? Email => _httpContextAccessor.HttpContext?.User?.FindFirstValue(ClaimTypes.Email);

    public bool IsAuthenticated => _httpContextAccessor.HttpContext?.User?.Identity?.IsAuthenticated ?? false;

    public List<string> Roles => _httpContextAccessor.HttpContext?.User?
        .Claims
        .Where(c =>
            c.Type == ClaimTypes.Role ||
            c.Type.Equals("role", StringComparison.OrdinalIgnoreCase) ||
            c.Type.Equals("roles", StringComparison.OrdinalIgnoreCase))
        .Select(c => c.Value)
        .Where(v => !string.IsNullOrWhiteSpace(v))
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .ToList() ?? new List<string>();

    public async Task<int?> GetInstitutionIdForCurrentUserAsync()
    {
        if (string.IsNullOrEmpty(UserId))
        {
            return null;
        }

        if (Roles.Contains(ApplicationRoles.SuperAdmin, StringComparer.OrdinalIgnoreCase))
        {
            return null;
        }

        var user = await _dbContext.Users
            .FirstOrDefaultAsync(u => u.Id == UserId);

        if (user == null)
        {
            return null;
        }

        var roleInstitutionId = await TryResolveInstitutionIdFromRolesAsync();
        if (roleInstitutionId.HasValue)
        {
            return roleInstitutionId.Value;
        }

        if (Roles.Any(r => ApplicationRoles.IsAdminRole(r) || ApplicationRoles.IsBlagajnikRole(r)))
        {
            if (user.InstitutionId.HasValue)
            {
                var institutionExists = await _dbContext.Institutions
                    .AnyAsync(i => i.Id == user.InstitutionId.Value && i.IsActive);
                
                if (institutionExists)
                {
                    return user.InstitutionId.Value;
                }
            }
            
            return null;
        }

        return null;
    }

    private async Task<int?> TryResolveInstitutionIdFromRolesAsync()
    {   
        string? ExtractCode(string role, string prefix)
        {
            var r = role.Trim();
            if (!r.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return null;
            var code = r.Substring(prefix.Length);
            return string.IsNullOrWhiteSpace(code) ? null : code.ToUpperInvariant();
        }

        var adminRole = Roles.FirstOrDefault(r => r.Trim().StartsWith("admin", StringComparison.OrdinalIgnoreCase) && r.Trim().Length > 4);
        var blagajnikRole = Roles.FirstOrDefault(r => r.Trim().StartsWith("blagajnik", StringComparison.OrdinalIgnoreCase) && r.Trim().Length > 8);

        var code = adminRole != null ? ExtractCode(adminRole, "admin") : null;
        code ??= blagajnikRole != null ? ExtractCode(blagajnikRole, "blagajnik") : null;

        if (string.IsNullOrWhiteSpace(code)) return null;

        if (!ApplicationRoles.InstitutionCodeToIdMap.TryGetValue(code, out var institutionId))
        {
            institutionId = 0;
        }

        // 1) Prefer ID map (ako postoji i aktivna je)
        if (institutionId > 0)
        {
            var byId = await _dbContext.Institutions.AnyAsync(i => i.Id == institutionId && i.IsActive);
            if (byId) return institutionId;
        }

        // 2) Fallback: nađi instituciju po nazivu (tolerantno na male razlike u nazivu)
        var needle = code switch
        {
            "NPS" => "Narodno pozorište",
            "POZM" => "Pozorište mladih",
            "CK" => "Centar kulture",
            _ => ApplicationRoles.GetInstitutionName(code)
        };

        var inst = await _dbContext.Institutions
            .Where(i => i.IsActive)
            .OrderBy(i => i.Id)
            .FirstOrDefaultAsync(i => i.Name.Contains(needle));

        return inst?.Id;
    }
}






