using FluentValidation;
using SApplauz.Shared.DTOs.Auth;

namespace SApplauz.Application.Validators;

public class RegisterRequestValidator : AbstractValidator<RegisterRequest>
{
    public RegisterRequestValidator()
    {
        RuleFor(x => x.FirstName)
            .NotEmpty().WithMessage("Nedostaje obavezno polje: Ime")
            .MaximumLength(100).WithMessage("Ime ne može biti duže od 100 karaktera.");

        RuleFor(x => x.LastName)
            .NotEmpty().WithMessage("Nedostaje obavezno polje: Prezime")
            .MaximumLength(100).WithMessage("Prezime ne može biti duže od 100 karaktera.");

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Nedostaje obavezno polje: Email")
            .EmailAddress().WithMessage("Email format nije validan.");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Nedostaje obavezno polje: Lozinka")
            .MinimumLength(4).WithMessage("Lozinka mora imati najmanje 4 znaka.")
            ;

        RuleFor(x => x.ConfirmPassword)
            .NotEmpty().WithMessage("Nedostaje obavezno polje: Potvrda lozinke")
            .Equal(x => x.Password).WithMessage("Lozinka i potvrda lozinke se ne podudaraju.");
    }
}






