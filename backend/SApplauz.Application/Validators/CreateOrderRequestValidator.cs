using FluentValidation;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Validators;

public class CreateOrderRequestValidator : AbstractValidator<CreateOrderRequest>
{
    public CreateOrderRequestValidator()
    {
        RuleFor(x => x.InstitutionId)
            .GreaterThan(0).WithMessage("ID institucije mora biti veći od 0.");

        RuleFor(x => x.OrderItems)
            .NotEmpty().WithMessage("Narudžba mora sadržavati najmanje jednu stavku.");

        RuleForEach(x => x.OrderItems)
            .SetValidator(new OrderItemRequestValidator());
    }
}

public class OrderItemRequestValidator : AbstractValidator<OrderItemRequest>
{
    public OrderItemRequestValidator()
    {
        RuleFor(x => x.PerformanceId)
            .GreaterThan(0).WithMessage("ID termina mora biti veći od 0.");

        RuleFor(x => x.Quantity)
            .GreaterThan(0).WithMessage("Količina mora biti veća od 0.")
            .LessThanOrEqualTo(10).WithMessage("Količina mora biti između 1 i 10.");
    }
}






