using FluentValidation;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Validators;

public class UpdateInstitutionRequestValidator : AbstractValidator<UpdateInstitutionRequest>
{
    public UpdateInstitutionRequestValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Naziv institucije je obavezan.")
            .MaximumLength(200).WithMessage("Naziv institucije ne može biti duži od 200 karaktera.");

        RuleFor(x => x.Description)
            .MaximumLength(1000).WithMessage("Opis ne može biti duži od 1000 karaktera.");

        RuleFor(x => x.Address)
            .MaximumLength(500).WithMessage("Adresa ne može biti duža od 500 karaktera.");

        RuleFor(x => x.Capacity)
            .GreaterThan(0).WithMessage("Kapacitet mora biti veći od 0.");

        RuleFor(x => x.ImagePath)
            .MaximumLength(500).WithMessage("Putanja slike ne može biti duža od 500 karaktera.");

        RuleFor(x => x.Website)
            .MaximumLength(500).WithMessage("Web stranica ne može biti duža od 500 karaktera.")
            .Must(uri => string.IsNullOrEmpty(uri) || Uri.TryCreate(uri, UriKind.Absolute, out _))
            .WithMessage("Web stranica mora biti validan URL.");
    }
}






