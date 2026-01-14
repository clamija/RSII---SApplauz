using AutoMapper;
using Microsoft.AspNetCore.Identity;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Infrastructure.Identity;
using SApplauz.Infrastructure.Services;
using SApplauz.Shared.DTOs;
using SApplauz.Shared.DTOs.Auth;

namespace SApplauz.Application.Services;

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IMapper _mapper;

    public AuthService(
        UserManager<ApplicationUser> userManager,
        SignInManager<ApplicationUser> signInManager,
        IJwtTokenService jwtTokenService,
        IMapper mapper)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _jwtTokenService = jwtTokenService;
        _mapper = mapper;
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request, string platform = "mobile")
    {
        // Login preko korisničkog imena (preferred) ili email-a radi backwards compatibility.
        var identifier = (request.Email ?? string.Empty).Trim();
        var user = await _userManager.FindByNameAsync(identifier);
        user ??= await _userManager.FindByEmailAsync(identifier);
        if (user == null)
        {
            throw new UnauthorizedAccessException("Neispravno korisničko ime ili lozinka.");
        }

        // Soft-deleted / deaktiviran korisnik
        if (!user.IsActive)
        {
            throw new UnauthorizedAccessException("Vaš nalog je deaktiviran.");
        }

        var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, lockoutOnFailure: false);
        if (!result.Succeeded)
        {
            throw new UnauthorizedAccessException("Neispravno korisničko ime ili lozinka.");
        }

        var roles = await _userManager.GetRolesAsync(user);
        
        // Provjeri pristup na osnovu platforme i uloga
        ValidatePlatformAccess(roles, platform);

        var token = _jwtTokenService.GenerateToken(user, roles);

        var userDto = _mapper.Map<UserDto>(user);
        userDto.Roles = roles.ToList();

        return new LoginResponse
        {
            Token = token,
            Expires = DateTime.UtcNow.AddMinutes(60),
            User = userDto
        };
    }

    private void ValidatePlatformAccess(IList<string> roles, string platform)
    {
        var normalizedPlatform = platform.ToLower();
        var hasAdminOrSuperAdmin = roles.Any(r => 
            ApplicationRoles.IsAdminRole(r) || 
            r.Equals(ApplicationRoles.SuperAdmin, StringComparison.OrdinalIgnoreCase));
        const string desktopBlockedMessage = "Molimo Vas da našu aplikaciju isprobate na mobilnom uređaju.";

        // Desktop aplikacija - blokiraj Blagajnika i običnog Korisnika (bez Admin/SuperAdmin uloge)
        // Napomena: SuperAdmin i Admin mogu pristupiti desktop aplikaciji
        if (normalizedPlatform == "desktop")
        {
            // Ako korisnik ima Admin ili SuperAdmin ulogu, dozvoli pristup
            if (hasAdminOrSuperAdmin)
            {
                return; // SuperAdmin i Admin mogu pristupiti desktop aplikaciji
            }
            
            // Provjeri da li korisnik ima samo Blagajnik ulogu (bez Admin/SuperAdmin)
            var isBlagajnikOnly = roles.Any(r => ApplicationRoles.IsBlagajnikRole(r)) && !hasAdminOrSuperAdmin;
            if (isBlagajnikOnly)
            {
                throw new UnauthorizedAccessException(desktopBlockedMessage);
            }
            
            // Provjeri da li korisnik ima samo Korisnik ulogu (bez Admin/SuperAdmin/Blagajnik)
            var hasBlagajnik = roles.Any(r => ApplicationRoles.IsBlagajnikRole(r));
            var isKorisnikOnly = roles.Any(r => r.Equals(ApplicationRoles.Korisnik, StringComparison.OrdinalIgnoreCase)) 
                                 && !hasAdminOrSuperAdmin 
                                 && !hasBlagajnik;
            if (isKorisnikOnly)
            {
                throw new UnauthorizedAccessException(desktopBlockedMessage);
            }
        }
        
        // Mobile aplikacija - sve uloge mogu pristupiti
        // (ne treba provjera jer sve uloge mogu koristiti mobile aplikaciju)
    }

    public async Task<RegisterResponse> RegisterAsync(RegisterRequest request)
    {
        if (request.Password != request.ConfirmPassword)
        {
            throw new ArgumentException("Password and confirm password do not match.");
        }

        var existingUser = await _userManager.FindByEmailAsync(request.Email);
        if (existingUser != null)
        {
            throw new InvalidOperationException("User with this email already exists.");
        }

        var user = new ApplicationUser
        {
            UserName = request.Email,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            CreatedAt = DateTime.UtcNow
        };

        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
        {
            var errors = string.Join(", ", result.Errors.Select(e => e.Description));
            throw new InvalidOperationException($"Failed to create user: {errors}");
        }

        // Assign default role
        await _userManager.AddToRoleAsync(user, ApplicationRoles.Korisnik);

        var userDto = _mapper.Map<UserDto>(user);
        userDto.Roles = new List<string> { ApplicationRoles.Korisnik };

        return new RegisterResponse
        {
            User = userDto,
            Message = "User registered successfully."
        };
    }
}

