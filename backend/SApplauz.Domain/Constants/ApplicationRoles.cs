namespace SApplauz.Domain.Constants;

public static class ApplicationRoles
{
    // Osnovne uloge - globalne uloge
    public const string SuperAdmin = "SuperAdmin";
    public const string Korisnik = "Korisnik";
    
    // Generičke uloge koje se vežu za instituciju kroz User.InstitutionId
    // Admin institucije - administrativna uloga vezana za jednu instituciju
    public const string Admin = "Admin";
    
    // Blagajnik institucije - operativna uloga vezana za jednu instituciju
    public const string Blagajnik = "Blagajnik";
    
    // Helper metode za provjeru tipa uloge
    public static bool IsAdminRole(string role)
    {
        if (string.IsNullOrWhiteSpace(role)) return false;
        var r = role.Trim();
        // Podrži i institucijske role tipa adminBKC, adminSARTR...
        return r.Equals(Admin, StringComparison.OrdinalIgnoreCase) ||
               (r.StartsWith("admin", StringComparison.OrdinalIgnoreCase) && r.Length > "admin".Length);
    }
    
    public static bool IsBlagajnikRole(string role)
    {
        if (string.IsNullOrWhiteSpace(role)) return false;
        var r = role.Trim();
        // Podrži i institucijske role tipa blagajnikBKC, blagajnikNPS...
        return r.Equals(Blagajnik, StringComparison.OrdinalIgnoreCase) ||
               (r.StartsWith("blagajnik", StringComparison.OrdinalIgnoreCase) && r.Length > "blagajnik".Length);
    }
    
    public static bool IsInstitutionRole(string role)
    {
        return IsAdminRole(role) || IsBlagajnikRole(role);
    }
    
    public static List<string> GetAllRoles()
    {
        var roles = new List<string> { SuperAdmin, Korisnik, Admin, Blagajnik };

        // Konkretne institucijske role koje UI očekuje (adminBKC, blagajnikSARTR, ...)
        foreach (var code in InstitutionCodeToIdMap.Keys)
        {
            roles.Add($"admin{code}");
            roles.Add($"blagajnik{code}");
        }

        return roles;
    }
    
    // Konstante za Authorize atribut (mora biti konstanta, ne metoda)
    // SuperAdmin ima pristup svim funkcionalnostima
    public const string AllAdminRoles = "SuperAdmin,Admin";
    // SuperAdmin, Admin i Blagajnik imaju pristup validaciji karata
    public const string AllAdminAndBlagajnikRoles = "SuperAdmin,Admin,Blagajnik";
    // Blagajnik može samo validirati karte (mobile isključivo)
    public const string AllBlagajnikRoles = "SuperAdmin,Admin,Blagajnik";
    
    // Mapiranje kodova institucija na imena (za prikaz) - zadržano za backward compatibility
    public static string GetInstitutionName(string code)
    {
        return code switch
        {
            "NPS" => "Narodno pozorište",
            "KT" => "Kamerni teatar 55",
            "SARTR" => "Sarajevski ratni teatar",
            "POZM" => "Pozorište mladih",
            "OS" => "Otvorena scena Obala",
            "CK" => "JU Centar kulture",
            "BKC" => "Bosanski kulturni centar",
            "DM" => "Dom mladih Skenderija",
            _ => code
        };
    }
    
    // Mapiranje kodova institucija na ID (zadržano za backward compatibility sa CurrentUserService)
    public static Dictionary<string, int> InstitutionCodeToIdMap = new()
    {
        { "NPS", 1 },     // Narodno pozorište Sarajevo
        { "KT", 2 },      // Kamerni teatar 55
        { "SARTR", 3 },   // Sarajevski ratni teatar
        { "POZM", 4 },    // Pozorište mladih Sarajevo
        { "OS", 5 },      // Otvorena scena Obala
        { "CK", 6 },      // JU Centar kulture i mladih
        { "BKC", 7 },     // Bosanski kulturni centar
        { "DM", 8 }       // Dom mladih Skenderija
    };
}





