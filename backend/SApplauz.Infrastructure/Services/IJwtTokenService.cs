using System.Security.Claims;
using SApplauz.Infrastructure.Identity;

namespace SApplauz.Infrastructure.Services;

public interface IJwtTokenService
{
    string GenerateToken(ApplicationUser user, IList<string> roles);
    ClaimsPrincipal? GetPrincipalFromToken(string token);
}

