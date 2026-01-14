using FluentValidation;
using SApplauz.Shared.DTOs.Auth;

namespace SApplauz.Application.Validators;

public class LoginRequestValidator : AbstractValidator<LoginRequest>
{
    public LoginRequestValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Nedostaje obavezno polje: Korisničko ime");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Nedostaje obavezno polje: Lozinka");
    }
}






