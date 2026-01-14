using FluentValidation;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Validators;

public class CreateShowRequestValidator : AbstractValidator<CreateShowRequest>
{
    public CreateShowRequestValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty().WithMessage("Naziv predstave je obavezan.")
            .MaximumLength(200).WithMessage("Naziv predstave ne može biti duži od 200 karaktera.");

        RuleFor(x => x.Description)
            .MaximumLength(2000).WithMessage("Opis ne može biti duži od 2000 karaktera.");

        RuleFor(x => x.DurationMinutes)
            .GreaterThan(0).WithMessage("Trajanje mora biti veće od 0 minuta.")
            .LessThanOrEqualTo(600).WithMessage("Trajanje ne može biti duže od 600 minuta (10 sati).");

        RuleFor(x => x.InstitutionId)
            .GreaterThan(0).WithMessage("ID institucije mora biti veći od 0.");

        RuleFor(x => x.GenreId)
            .GreaterThan(0).WithMessage("ID žanra mora biti veći od 0.");

        RuleFor(x => x.ImagePath)
            .MaximumLength(500).WithMessage("Putanja slike ne može biti duža od 500 karaktera.");
    }
}






