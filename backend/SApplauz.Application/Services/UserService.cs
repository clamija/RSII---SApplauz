using AutoMapper;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Services;

public class UserService : IUserService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly RoleManager<IdentityRole> _roleManager;
    private readonly IMapper _mapper;

    public UserService(
        UserManager<ApplicationUser> userManager,
        RoleManager<IdentityRole> roleManager,
        IMapper mapper)
    {
        _userManager = userManager;
        _roleManager = roleManager;
        _mapper = mapper;
    }

    public async Task<UserDto?> GetUserByIdAsync(string id)
    {
        var user = await _userManager.FindByIdAsync(id);
        if (user == null)
        {
            return null;
        }

        var roles = await _userManager.GetRolesAsync(user);
        var userDto = _mapper.Map<UserDto>(user);
        userDto.Roles = roles.ToList();

        return userDto;
    }

    public async Task<UserDto> UpdateUserAsync(string id, UpdateUserRequest request)
    {
        var user = await _userManager.FindByIdAsync(id);
        if (user == null)
        {
            throw new KeyNotFoundException($"User with id {id} not found.");
        }

        user.FirstName = request.FirstName;
        user.LastName = request.LastName;
        user.Email = request.Email;
        user.UserName = request.Email;
        user.NormalizedEmail = _userManager.NormalizeEmail(request.Email);
        user.NormalizedUserName = _userManager.NormalizeName(request.Email);
        user.UpdatedAt = DateTime.UtcNow;

        var result = await _userManager.UpdateAsync(user);
        if (!result.Succeeded)
        {
            var errors = string.Join(", ", result.Errors.Select(e => e.Description));
            throw new InvalidOperationException($"Failed to update user: {errors}");
        }

        if (!string.IsNullOrEmpty(request.NewPassword))
        {
            if (request.NewPassword.Length < 4)
            {
                throw new InvalidOperationException("Lozinka mora imati najmanje 4 znaka.");
            }

            if (string.IsNullOrEmpty(request.CurrentPassword))
            {
                throw new InvalidOperationException("Trenutna lozinka je obavezna za promjenu lozinke.");
            }

            var passwordValid = await _userManager.CheckPasswordAsync(user, request.CurrentPassword);
            if (!passwordValid)
            {
                throw new InvalidOperationException("Trenutna lozinka nije tačna.");
            }

            var changePasswordResult = await _userManager.ChangePasswordAsync(user, request.CurrentPassword, request.NewPassword);
            
            if (!changePasswordResult.Succeeded)
            {
                var errors = string.Join(", ", changePasswordResult.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Promjena lozinke nije uspjela: {errors}");
            }
        }

        var roles = await _userManager.GetRolesAsync(user);
        var userDto = _mapper.Map<UserDto>(user);
        userDto.Roles = roles.ToList();

        return userDto;
    }

    public async Task<UserDto> CreateUserAsync(CreateUserRequest request)
    {
        var existingUser = await _userManager.FindByEmailAsync(request.Email);
        if (existingUser != null)
        {
            throw new InvalidOperationException($"User with email {request.Email} already exists.");
        }

        var user = new ApplicationUser
        {
            FirstName = request.FirstName,
            LastName = request.LastName,
            Email = request.Email,
            UserName = request.Email,
            EmailConfirmed = true,
            CreatedAt = DateTime.UtcNow
        };

        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
        {
            var errors = string.Join(", ", result.Errors.Select(e => e.Description));
            throw new InvalidOperationException($"Failed to create user: {errors}");
        }

        if (request.Roles.Any())
        {
            var validRoles = await GetAvailableRolesAsync();
            var rolesToAssign = request.Roles
                .Select(r => r?.Trim())
                .Where(r => !string.IsNullOrWhiteSpace(r))
                .Select(r => validRoles.FirstOrDefault(v => v.Equals(r!, StringComparison.OrdinalIgnoreCase)))
                .Where(v => !string.IsNullOrWhiteSpace(v))
                .Select(v => v!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
            
            if (rolesToAssign.Any())
            {
                result = await _userManager.AddToRolesAsync(user, rolesToAssign);
                if (!result.Succeeded)
                {
                    var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                    throw new InvalidOperationException($"Failed to assign roles: {errors}");
                }
            }
        }
        else
        {
            await _userManager.AddToRoleAsync(user, ApplicationRoles.Korisnik);
        }

        var assignedRoles = await _userManager.GetRolesAsync(user);
        var resolvedInstitutionId = TryResolveInstitutionIdFromRoles(assignedRoles);
        if (resolvedInstitutionId.HasValue)
        {
            user.InstitutionId = resolvedInstitutionId.Value;
            await _userManager.UpdateAsync(user);
        }
        else
        {
            user.InstitutionId = null;
            await _userManager.UpdateAsync(user);
        }

        var roles = await _userManager.GetRolesAsync(user);
        var userDto = _mapper.Map<UserDto>(user);
        userDto.Roles = roles.ToList();

        return userDto;
    }

    public async Task<UserListResponse> GetUsersAsync(int pageNumber = 1, int pageSize = 10, string? searchTerm = null)
    {
        var query = _userManager.Users.Where(u => u.IsActive).AsQueryable();

        if (!string.IsNullOrWhiteSpace(searchTerm))
        {
            var terms = searchTerm
                .Trim()
                .ToLower()
                .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            foreach (var term in terms)
            {
                var t = term;
                query = query.Where(u =>
                    (u.FirstName != null && u.FirstName.ToLower().Contains(t)) ||
                    (u.LastName != null && u.LastName.ToLower().Contains(t)) ||
                    (u.Email != null && u.Email.ToLower().Contains(t)));
            }
        }

        var totalCount = await query.CountAsync();

        var users = await query
            .OrderBy(u => u.LastName)
            .ThenBy(u => u.FirstName)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var userDtos = new List<UserDto>();
        foreach (var user in users)
        {
            var roles = await _userManager.GetRolesAsync(user);
            var userDto = _mapper.Map<UserDto>(user);
            userDto.Roles = roles.ToList();
            userDtos.Add(userDto);
        }

        return new UserListResponse
        {
            Users = userDtos,
            TotalCount = totalCount,
            PageNumber = pageNumber,
            PageSize = pageSize
        };
    }

    public async Task<bool> DeleteUserAsync(string userId)
    {
        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return false;
        }

        try
        {
            var hardDeleteResult = await _userManager.DeleteAsync(user);
            if (hardDeleteResult.Succeeded) return true;
        }
        catch (DbUpdateException)
        {
        }
        catch (Exception)
        {
                    }

        user.IsActive = false;
        user.UpdatedAt = DateTime.UtcNow;
        user.LockoutEnabled = true;
        user.LockoutEnd = DateTimeOffset.UtcNow.AddYears(100);

        var updateResult = await _userManager.UpdateAsync(user);
        if (!updateResult.Succeeded) return false;

        var roles = await _userManager.GetRolesAsync(user);
        if (roles.Any())
        {
            await _userManager.RemoveFromRolesAsync(user, roles);
        }

        return true;
    }

    public async Task<UserDto> UpdateUserRolesAsync(string userId, UpdateUserRolesRequest request)
    {
        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            throw new KeyNotFoundException($"User with id {userId} not found.");
        }

        var availableRoles = await GetAvailableRolesAsync();
        var rolesToAssign = request.Roles
            .Select(r => r?.Trim())
            .Where(r => !string.IsNullOrWhiteSpace(r))
            .Select(r => availableRoles.FirstOrDefault(v => v.Equals(r!, StringComparison.OrdinalIgnoreCase)))
            .Where(v => !string.IsNullOrWhiteSpace(v))
            .Select(v => v!)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        var currentRoles = await _userManager.GetRolesAsync(user);

        var rolesToRemove = currentRoles.Except(rolesToAssign).ToList();
        if (rolesToRemove.Any())
        {
            var removeResult = await _userManager.RemoveFromRolesAsync(user, rolesToRemove);
            if (!removeResult.Succeeded)
            {
                var errors = string.Join(", ", removeResult.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Failed to remove roles: {errors}");
            }
        }

        var rolesToAdd = rolesToAssign.Except(currentRoles).ToList();
        if (rolesToAdd.Any())
        {
            var addResult = await _userManager.AddToRolesAsync(user, rolesToAdd);
            if (!addResult.Succeeded)
            {
                var errors = string.Join(", ", addResult.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Failed to add roles: {errors}");
            }
        }

        var finalRoles = await _userManager.GetRolesAsync(user);
        var institutionId = TryResolveInstitutionIdFromRoles(finalRoles);
        user.InstitutionId = institutionId;
        user.UpdatedAt = DateTime.UtcNow;
        await _userManager.UpdateAsync(user);

        var updatedRoles = await _userManager.GetRolesAsync(user);
        var userDto = _mapper.Map<UserDto>(user);
        userDto.Roles = updatedRoles.ToList();

        return userDto;
    }

    public async Task<List<string>> GetAvailableRolesAsync()
    {
        var roles = await _roleManager.Roles
            .Select(r => r.Name!)
            .ToListAsync();

        roles = roles
            .Where(r =>
                !r.Equals(ApplicationRoles.Admin, StringComparison.OrdinalIgnoreCase) &&
                !r.Equals(ApplicationRoles.Blagajnik, StringComparison.OrdinalIgnoreCase))
            .OrderBy(r => r)
            .ToList();

        return roles;
    }

    private static int? TryResolveInstitutionIdFromRoles(IEnumerable<string> roles)
    {
        string? ExtractCode(string role, string prefix)
        {
            var r = (role ?? string.Empty).Trim();
            if (!r.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return null;
            var code = r.Substring(prefix.Length);
            return string.IsNullOrWhiteSpace(code) ? null : code.ToUpperInvariant();
        }

        foreach (var role in roles)
        {
            var code = ExtractCode(role, "admin") ?? ExtractCode(role, "blagajnik");
            if (string.IsNullOrWhiteSpace(code)) continue;
            if (ApplicationRoles.InstitutionCodeToIdMap.TryGetValue(code, out var id))
            {
                return id;
            }
        }

        return null;
    }
}

