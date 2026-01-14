namespace SApplauz.Shared.DTOs;

public class UpdateUserRequest
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? CurrentPassword { get; set; } // Required only if changing password
    public string? NewPassword { get; set; } // Optional - only if user wants to change password
}






