using FluentValidation;
using SApplauz.Shared.DTOs;

namespace SApplauz.Application.Validators;

public class UpdatePerformanceRequestValidator : AbstractValidator<UpdatePerformanceRequest>
{
    public UpdatePerformanceRequestValidator()
    {
        RuleFor(x => x.ShowId)
            .GreaterThan(0).WithMessage("ID predstave mora biti veći od 0.");

        RuleFor(x => x.StartTime)
            .NotEmpty().WithMessage("Vrijeme početka je obavezno.")
            .Must(BeInFuture).WithMessage("Vrijeme početka mora biti u budućnosti.");

        RuleFor(x => x.Price)
            .GreaterThanOrEqualTo(0).WithMessage("Cijena ne može biti negativna.");
    }

    private bool BeInFuture(DateTime dateTime)
    {
        var tz = GetAppTimeZone();
        var nowLocal = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
        var candidateLocal = NormalizeToAppLocalUnspecified(dateTime, tz);
        return candidateLocal > DateTime.SpecifyKind(nowLocal, DateTimeKind.Unspecified);
    }

    private static DateTime NormalizeToAppLocalUnspecified(DateTime dt, TimeZoneInfo tz)
    {
        DateTime local;

        if (dt.Kind == DateTimeKind.Utc)
        {
            local = TimeZoneInfo.ConvertTimeFromUtc(dt, tz);
        }
        else if (dt.Kind == DateTimeKind.Local)
        {
            local = TimeZoneInfo.ConvertTime(dt, tz);
        }
        else
        {
            local = dt;
        }

        return DateTime.SpecifyKind(local, DateTimeKind.Unspecified);
    }

    private static TimeZoneInfo GetAppTimeZone()
    {
        try { return TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo"); } catch { /* ignore */ }
        try { return TimeZoneInfo.FindSystemTimeZoneById("Central European Standard Time"); } catch { /* ignore */ }
        return TimeZoneInfo.Local;
    }
}






