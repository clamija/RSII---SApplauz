using FluentValidation;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Validators;

public class CreateGenreRequestValidator : AbstractValidator<CreateGenreRequest>
{
    public CreateGenreRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Naziv žanra je obavezan.")
            .MaximumLength(100).WithMessage("Naziv žanra ne može biti duži od 100 karaktera.");
    }
}






