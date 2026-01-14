using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Interfaces;

public interface IUserService
{
    // Existing
    Task<UserDto?> GetUserByIdAsync(string id);
    Task<UserDto> UpdateUserAsync(string id, UpdateUserRequest request);
    
    // New CRUD operations
    Task<UserDto> CreateUserAsync(CreateUserRequest request);
    Task<UserListResponse> GetUsersAsync(int pageNumber = 1, int pageSize = 10, string? searchTerm = null);
    Task<bool> DeleteUserAsync(string userId);
    Task<UserDto> UpdateUserRolesAsync(string userId, UpdateUserRolesRequest request);
    Task<List<string>> GetAvailableRolesAsync();
}

