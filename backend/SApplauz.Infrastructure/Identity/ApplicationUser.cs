using Microsoft.AspNetCore.Identity;
using SApplauz.Domain.Entities;

namespace SApplauz.Infrastructure.Identity;

public class ApplicationUser : IdentityUser
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
    
    // InstitutionId - nullable, postavlja se samo za Admin i Blagajnik uloge
    // SuperAdmin i Korisnik nemaju InstitutionId (mogu pristupiti svim institucijama)
    public int? InstitutionId { get; set; }
    
    // Navigation properties (configured in ApplicationDbContext)
    public Institution? Institution { get; set; }
    public ICollection<Order> Orders { get; set; } = new List<Order>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
    public ICollection<RecommendationProfile> RecommendationProfiles { get; set; } = new List<RecommendationProfile>();
}

