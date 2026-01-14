using FluentValidation;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Validators;

public class UpdateUserRequestValidator : AbstractValidator<UpdateUserRequest>
{
    public UpdateUserRequestValidator()
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

        When(x => !string.IsNullOrEmpty(x.NewPassword), () =>
        {
            RuleFor(x => x.NewPassword)
                .NotEmpty().WithMessage("Nova lozinka je obavezna.")
                .MinimumLength(4).WithMessage("Lozinka mora imati najmanje 4 znaka.");

            RuleFor(x => x.CurrentPassword)
                .NotEmpty().WithMessage("Trenutna lozinka je obavezna za promjenu lozinke.");
        });
    }
}






