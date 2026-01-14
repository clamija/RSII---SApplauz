using SApplauz.Shared.DTOs.Auth;

namespace SApplauz.Application.Interfaces;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest request, string platform = "mobile");
    Task<RegisterResponse> RegisterAsync(RegisterRequest request);
}






