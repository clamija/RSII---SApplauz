using System.Security.Claims;
using System.Linq;
using Microsoft.AspNetCore.Authentication;
using SApplauz.Domain.Constants;

namespace SApplauz.API.Security;

/// <summary>
/// Normalizuje role claim-ove da bi autorizacija bila robustna čak i ako su role u bazi/token-u različitog casing-a
/// (npr. "superadmin" vs "SuperAdmin").
/// </summary>
public class RoleClaimsTransformation : IClaimsTransformation
{
    public Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        if (principal.Identity is not ClaimsIdentity identity)
        {
            return Task.FromResult(principal);
        }

        var existingRoles = identity.FindAll(identity.RoleClaimType).Select(c => c.Value).ToList();
        if (existingRoles.Count == 0)
        {
            return Task.FromResult(principal);
        }

        // Bitno: Role authorization u praksi može biti case-sensitive.
        // Zato ovdje koristimo EXACT set da bismo dodali normalizovanu rolu čak i ako postoji samo u drugom casing-u.
        var exactRoleSet = new HashSet<string>(existingRoles, StringComparer.Ordinal);

        foreach (var role in existingRoles)
        {
            var normalized = NormalizeRole(role);
            if (!string.IsNullOrWhiteSpace(normalized) && !exactRoleSet.Contains(normalized))
            {
                identity.AddClaim(new Claim(identity.RoleClaimType, normalized));
                exactRoleSet.Add(normalized);
            }

            // Ako korisnik ima institucijsku rolu tipa adminBKC/blagajnikSARTR,
            // dodaj i baznu rolu Admin/Blagajnik da bi [Authorize(Roles=...)] radio bez nabrajanja svih institucija.
            if (IsInstitutionAdminRole(role) && !exactRoleSet.Contains(ApplicationRoles.Admin))
            {
                identity.AddClaim(new Claim(identity.RoleClaimType, ApplicationRoles.Admin));
                exactRoleSet.Add(ApplicationRoles.Admin);
            }
            if (IsInstitutionBlagajnikRole(role) && !exactRoleSet.Contains(ApplicationRoles.Blagajnik))
            {
                identity.AddClaim(new Claim(identity.RoleClaimType, ApplicationRoles.Blagajnik));
                exactRoleSet.Add(ApplicationRoles.Blagajnik);
            }
        }

        return Task.FromResult(principal);
    }

    private static bool IsInstitutionAdminRole(string? role)
    {
        var r = (role ?? string.Empty).Trim();
        return r.StartsWith("admin", StringComparison.OrdinalIgnoreCase) && r.Length > "admin".Length;
    }

    private static bool IsInstitutionBlagajnikRole(string? role)
    {
        var r = (role ?? string.Empty).Trim();
        return r.StartsWith("blagajnik", StringComparison.OrdinalIgnoreCase) && r.Length > "blagajnik".Length;
    }

    private static string NormalizeRole(string? role)
    {
        var r = (role ?? string.Empty).Trim();
        if (r.Equals(ApplicationRoles.SuperAdmin, StringComparison.OrdinalIgnoreCase)) return ApplicationRoles.SuperAdmin;
        if (r.Equals(ApplicationRoles.Admin, StringComparison.OrdinalIgnoreCase)) return ApplicationRoles.Admin;
        if (r.Equals(ApplicationRoles.Blagajnik, StringComparison.OrdinalIgnoreCase)) return ApplicationRoles.Blagajnik;
        if (r.Equals(ApplicationRoles.Korisnik, StringComparison.OrdinalIgnoreCase)) return ApplicationRoles.Korisnik;
        return r;
    }
}

