namespace SApplauz.Shared.DTOs;

public class RecommendationDto
{
    public ShowDto Show { get; set; } = new();
    public double Score { get; set; } // 0.0 - 1.0, gdje 1.0 je najbolja preporuka
    public string Reason { get; set; } = string.Empty; // Objašnjenje zašto je preporučeno
}






