namespace SApplauz.Application.Interfaces;

public interface ICurrentUserService
{
    string? UserId { get; }
    string? Email { get; }
    bool IsAuthenticated { get; }
    List<string> Roles { get; }
    
    /// <summary>
    /// Vraća InstitutionId za trenutnog korisnika na osnovu njegovih uloga.
    /// - SuperAdmin i Korisnik: vraća null (vidi sve institucije)
    /// - Admin/Blagajnik: vraća InstitutionId iz uloge (samo svoju instituciju)
    /// </summary>
    Task<int?> GetInstitutionIdForCurrentUserAsync();
}






