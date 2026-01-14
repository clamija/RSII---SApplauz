using SApplauz.Shared.DTOs;

namespace SApplauz.Shared.DTOs.Auth;

public class RegisterResponse
{
    public UserDto User { get; set; } = null!;
    public string Message { get; set; } = string.Empty;
}






