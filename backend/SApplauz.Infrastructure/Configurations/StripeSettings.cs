namespace SApplauz.Infrastructure.Configurations;

public class StripeSettings
{
    public string SecretKey { get; set; } = string.Empty;
    public string PublishableKey { get; set; } = string.Empty;
    public string WebhookSecret { get; set; } = string.Empty;
    /// <summary>
    /// Stripe test token za testiranje (tok_visa, tok_mastercard, itd.)
    /// Koristi se umjesto direktnog slanja kartičnih podataka u test mode-u
    /// </summary>
    public string? TestToken { get; set; }
}



