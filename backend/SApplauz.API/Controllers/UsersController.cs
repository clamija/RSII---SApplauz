using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Shared.DTOs;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly ICurrentUserService _currentUserService;
    private readonly ILogger<UsersController> _logger;

    public UsersController(
        IUserService userService,
        ICurrentUserService currentUserService,
        ILogger<UsersController> logger)
    {
        _userService = userService;
        _currentUserService = currentUserService;
        _logger = logger;
    }

    /// <summary>
    /// Get list of users with pagination and search
    /// </summary>
    [HttpGet]
    [Authorize(Roles = ApplicationRoles.AllAdminAndBlagajnikRoles)]
    public async Task<ActionResult<UserListResponse>> GetUsers(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? search = null)
    {
        try
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 100) pageSize = 10;

            var response = await _userService.GetUsersAsync(page, pageSize, search);
            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting users list");
            return StatusCode(500, new { message = "An error occurred while getting users." });
        }
    }

    /// <summary>
    /// Get user by ID
    /// </summary>
    [HttpGet("{id}")]
    [Authorize(Roles = ApplicationRoles.AllAdminAndBlagajnikRoles)]
    public async Task<ActionResult<UserDto>> GetUser(string id)
    {
        try
        {
            var user = await _userService.GetUserByIdAsync(id);
            if (user == null)
            {
                return NotFound(new { message = "User not found." });
            }

            return Ok(user);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting user {UserId}", id);
            return StatusCode(500, new { message = "An error occurred while getting user." });
        }
    }

    /// <summary>
    /// Get current authenticated user
    /// </summary>
    [HttpGet("me")]
    public async Task<ActionResult<UserDto>> GetCurrentUser()
    {
        try
        {
            if (!_currentUserService.IsAuthenticated || string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "User is not authenticated." });
            }

            var user = await _userService.GetUserByIdAsync(_currentUserService.UserId);
            if (user == null)
            {
                return NotFound(new { message = "User not found." });
            }

            return Ok(user);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting current user");
            return StatusCode(500, new { message = "An error occurred while getting user information." });
        }
    }

    /// <summary>
    /// Update current authenticated user profile
    /// </summary>
    [HttpPut("me")]
    public async Task<ActionResult<UserDto>> UpdateCurrentUser([FromBody] UpdateUserRequest request)
    {
        try
        {
            if (!_currentUserService.IsAuthenticated || string.IsNullOrEmpty(_currentUserService.UserId))
            {
                return Unauthorized(new { message = "User is not authenticated." });
            }

            var user = await _userService.UpdateUserAsync(_currentUserService.UserId, request);
            return Ok(user);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating current user profile");
            return StatusCode(500, new { message = "An error occurred while updating profile." });
        }
    }

    /// <summary>
    /// Create a new user
    /// </summary>
    [HttpPost]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<UserDto>> CreateUser([FromBody] CreateUserRequest request)
    {
        try
        {
            var user = await _userService.CreateUserAsync(request);
            return CreatedAtAction(nameof(GetUser), new { id = user.Id }, user);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating user");
            return StatusCode(500, new { message = "An error occurred while creating user." });
        }
    }

    /// <summary>
    /// Update user information
    /// </summary>
    [HttpPut("{id}")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<UserDto>> UpdateUser(string id, [FromBody] UpdateUserRequest request)
        {
            try
            {
                // Allow users to update their own profile, or admins to update any profile
                if (!_currentUserService.IsAuthenticated || 
                    (_currentUserService.UserId != id && 
                     !_currentUserService.Roles.Contains(ApplicationRoles.SuperAdmin, StringComparer.OrdinalIgnoreCase) && 
                     !_currentUserService.Roles.Any(role => ApplicationRoles.IsAdminRole(role))))
                {
                    return Forbid("You don't have permission to update this user.");
                }

            var user = await _userService.UpdateUserAsync(id, request);
            return Ok(user);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating user {UserId}", id);
            return StatusCode(500, new { message = "An error occurred while updating user." });
        }
    }

    /// <summary>
    /// Delete a user (only SuperAdmin)
    /// </summary>
    [HttpDelete("{id}")]
    [Authorize(Roles = ApplicationRoles.SuperAdmin)]
    public async Task<IActionResult> DeleteUser(string id)
    {
        try
        {
            // Prevent self-deletion
            if (_currentUserService.UserId == id)
            {
                return BadRequest(new { message = "You cannot delete your own account." });
            }

            var result = await _userService.DeleteUserAsync(id);
            if (!result)
            {
                return NotFound(new { message = "User not found." });
            }

            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting user {UserId}", id);
            return StatusCode(500, new { message = "An error occurred while deleting user." });
        }
    }

    /// <summary>
    /// Update user roles
    /// </summary>
    [HttpPut("{id}/roles")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<UserDto>> UpdateUserRoles(string id, [FromBody] UpdateUserRolesRequest request)
        {
            try
            {
                // Prevent non-SuperAdmin from assigning/removing SuperAdmin role
                if (!_currentUserService.Roles.Contains(ApplicationRoles.SuperAdmin, StringComparer.OrdinalIgnoreCase) && 
                    request.Roles.Any(r => r.Equals(ApplicationRoles.SuperAdmin, StringComparison.OrdinalIgnoreCase)))
                {
                    return Forbid("Only SuperAdmin can assign SuperAdmin role.");
                }

            var user = await _userService.UpdateUserRolesAsync(id, request);
            return Ok(user);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating user roles for {UserId}", id);
            return StatusCode(500, new { message = "An error occurred while updating user roles." });
        }
    }

    /// <summary>
    /// Get available roles
    /// </summary>
    [HttpGet("roles")]
    [Authorize(Roles = ApplicationRoles.AllAdminRoles)]
    public async Task<ActionResult<List<string>>> GetAvailableRoles()
    {
        try
        {
            var roles = await _userService.GetAvailableRolesAsync();
            return Ok(roles);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting available roles");
            return StatusCode(500, new { message = "An error occurred while getting roles." });
        }
    }
}

