using FluentValidation;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Validators;

public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.FirstName)
            .NotEmpty().WithMessage("Ime je obavezno.")
            .MaximumLength(50).WithMessage("Ime ne može biti duže od 50 karaktera.");

        RuleFor(x => x.LastName)
            .NotEmpty().WithMessage("Prezime je obavezno.")
            .MaximumLength(50).WithMessage("Prezime ne može biti duže od 50 karaktera.");

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email je obavezan.")
            .EmailAddress().WithMessage("Email format nije ispravan.");

        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Lozinka je obavezna.")
            .MinimumLength(4).WithMessage("Lozinka mora imati najmanje 4 znaka.")
            ;

        RuleFor(x => x.Roles)
            .NotNull().WithMessage("Uloge su obavezne.");
    }
}






