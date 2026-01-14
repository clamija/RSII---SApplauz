using FluentValidation;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Validators;

public class UpdateUserRolesRequestValidator : AbstractValidator<UpdateUserRolesRequest>
{
    public UpdateUserRolesRequestValidator()
    {
        RuleFor(x => x.Roles)
            .NotNull().WithMessage("Uloge su obavezne.")
            .Must(roles => roles != null && roles.Any()).WithMessage("Korisnik mora imati najmanje jednu ulogu.");
    }
}






