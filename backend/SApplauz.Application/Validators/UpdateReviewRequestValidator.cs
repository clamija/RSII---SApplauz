using FluentValidation;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Validators;

public class UpdateReviewRequestValidator : AbstractValidator<UpdateReviewRequest>
{
    public UpdateReviewRequestValidator()
    {
        RuleFor(x => x.Rating)
            .InclusiveBetween(1, 5).WithMessage("Ocjena mora biti između 1 i 5.");

        RuleFor(x => x.Comment)
            .MaximumLength(2000).WithMessage("Komentar ne može biti duži od 2000 karaktera.");
    }
}






