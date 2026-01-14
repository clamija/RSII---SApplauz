using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SApplauz.Domain.Constants;
using SApplauz.Infrastructure.Configurations;
using SApplauz.Infrastructure.Identity;

namespace SApplauz.Infrastructure.Services;

public class JwtTokenService : IJwtTokenService
{
    private readonly JwtSettings _jwtSettings;
    private readonly JwtSecurityTokenHandler _tokenHandler;

    public JwtTokenService(IOptions<JwtSettings> jwtSettings)
    {
        _jwtSettings = jwtSettings.Value;
        _tokenHandler = new JwtSecurityTokenHandler();
    }

    public string GenerateToken(ApplicationUser user, IList<string> roles)
    {
        var key = Encoding.UTF8.GetBytes(_jwtSettings.SecretKey);
        var symmetricKey = new SymmetricSecurityKey(key);
        var signingCredentials = new SigningCredentials(symmetricKey, SecurityAlgorithms.HmacSha256Signature);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id),
            new(ClaimTypes.Email, user.Email ?? string.Empty),
            new(ClaimTypes.Name, user.UserName ?? string.Empty),
            new("firstName", user.FirstName),
            new("lastName", user.LastName)
        };

        // Add role claims
        var uniqueNormalizedRoles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var role in roles ?? Array.Empty<string>())
        {
            var normalized = NormalizeRole(role);
            if (!string.IsNullOrWhiteSpace(normalized) && uniqueNormalizedRoles.Add(normalized))
            {
                claims.Add(new Claim(ClaimTypes.Role, normalized));
            }

            // Ako je rola tipa adminBKC/blagajnikSARTR, dodaj i baznu rolu
            // da bi [Authorize(Roles=...)] radio bez nabrajanja svih institucijskih rola.
            if (IsInstitutionAdminRole(role) && uniqueNormalizedRoles.Add(ApplicationRoles.Admin))
            {
                claims.Add(new Claim(ClaimTypes.Role, ApplicationRoles.Admin));
            }
            if (IsInstitutionBlagajnikRole(role) && uniqueNormalizedRoles.Add(ApplicationRoles.Blagajnik))
            {
                claims.Add(new Claim(ClaimTypes.Role, ApplicationRoles.Blagajnik));
            }
        }

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddMinutes(_jwtSettings.ExpirationInMinutes),
            Issuer = _jwtSettings.Issuer,
            Audience = _jwtSettings.Audience,
            SigningCredentials = signingCredentials
        };

        var token = _tokenHandler.CreateToken(tokenDescriptor);
        return _tokenHandler.WriteToken(token);
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

    public ClaimsPrincipal? GetPrincipalFromToken(string token)
    {
        try
        {
            var key = Encoding.UTF8.GetBytes(_jwtSettings.SecretKey);
            var symmetricKey = new SymmetricSecurityKey(key);

            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = symmetricKey,
                ValidateIssuer = true,
                ValidIssuer = _jwtSettings.Issuer,
                ValidateAudience = true,
                ValidAudience = _jwtSettings.Audience,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.Zero
            };

            var principal = _tokenHandler.ValidateToken(token, validationParameters, out SecurityToken validatedToken);
            return principal;
        }
        catch
        {
            return null;
        }
    }
}






