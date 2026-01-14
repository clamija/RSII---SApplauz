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
        // Podrži i JWT claim tipove "role"/"roles" (u nekim konfiguracijama se ne mapiraju na ClaimTypes.Role)
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

        // SuperAdmin vidi sve institucije (nema InstitutionId ograničenje)
        if (Roles.Contains(ApplicationRoles.SuperAdmin, StringComparer.OrdinalIgnoreCase))
        {
            return null;
        }

        // Pronađi korisnika u bazi da dobijemo InstitutionId
        var user = await _dbContext.Users
            .FirstOrDefaultAsync(u => u.Id == UserId);

        if (user == null)
        {
            return null;
        }

        // 1) Ako korisnik ima Admin/Blagajnik institucijsku rolu, pokušaj izvući InstitutionId iz same role (adminBKC/blagajnikSARTR...)
        // Ovo omogućava rad sistema čak i ako InstitutionId nije upisan u tabeli korisnika.
        var roleInstitutionId = await TryResolveInstitutionIdFromRolesAsync();
        if (roleInstitutionId.HasValue)
        {
            return roleInstitutionId.Value;
        }

        // Ako korisnik ima Admin ili Blagajnik ulogu, vrati InstitutionId
        if (Roles.Any(r => ApplicationRoles.IsAdminRole(r) || ApplicationRoles.IsBlagajnikRole(r)))
        {
            // Provjeri da li institucija postoji u bazi i da li je aktivna
            if (user.InstitutionId.HasValue)
            {
                var institutionExists = await _dbContext.Institutions
                    .AnyAsync(i => i.Id == user.InstitutionId.Value && i.IsActive);
                
                if (institutionExists)
                {
                    return user.InstitutionId.Value;
                }
            }
            
            // Ako Admin/Blagajnik nema InstitutionId ili institucija ne postoji, vrati null (greška u podacima)
            return null;
        }

        // Korisnik bez Admin/Blagajnik uloge (običan Korisnik) vidi sve institucije
        return null;
    }

    private async Task<int?> TryResolveInstitutionIdFromRolesAsync()
    {
        // očekivani formati: adminBKC, blagajnikSARTR...
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
            return null;
        }

        var institutionExists = await _dbContext.Institutions.AnyAsync(i => i.Id == institutionId && i.IsActive);
        return institutionExists ? institutionId : null;
    }
}






