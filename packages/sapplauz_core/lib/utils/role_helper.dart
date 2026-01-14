class RoleHelper {
  // Generičke uloge (prema backend ApplicationRoles)
  static const String superAdmin = 'SuperAdmin';
  static const String admin = 'Admin';
  static const String blagajnik = 'Blagajnik';
  static const String korisnik = 'Korisnik';

  // Mapiranje kodova institucija na ID (mora biti usklađeno sa backend `ApplicationRoles.InstitutionCodeToIdMap`)
  static const Map<String, int> _institutionCodeToId = {
    'NPS': 1,
    'KT': 2,
    'SARTR': 3,
    'POZM': 4,
    'OS': 5,
    'CK': 6,
    'BKC': 7,
    'DM': 8,
  };

  // Reverse map: institution ID -> code (za naming/export i UI gdje treba skraćenica)
  static const Map<int, String> _institutionIdToCode = {
    1: 'NPS',
    2: 'KT',
    3: 'SARTR',
    4: 'POZM',
    5: 'OS',
    6: 'CK',
    7: 'BKC',
    8: 'DM',
  };

  static String? tryGetInstitutionCodeFromId(int? institutionId) {
    if (institutionId == null) return null;
    return _institutionIdToCode[institutionId];
  }

  static bool hasRole(List<String> userRoles, String requiredRole) {
    // Case-insensitive provjera za kompatibilnost
    return userRoles.any((role) => role.toLowerCase() == requiredRole.toLowerCase());
  }

  static bool hasAnyRole(List<String> userRoles, List<String> requiredRoles) {
    return requiredRoles.any((role) => hasRole(userRoles, role));
  }

  static bool isSuperAdmin(List<String> userRoles) {
    return hasRole(userRoles, superAdmin);
  }

  static bool isAdmin(List<String> userRoles) {
    // Provjeri da li ima SuperAdmin ili bilo koju Admin ulogu (uključujući adminBKC, adminKT...)
    if (hasRole(userRoles, superAdmin)) return true;
    return userRoles.any((r) {
      final role = r.trim().toLowerCase();
      return role == admin.toLowerCase() || (role.startsWith('admin') && role.length > 'admin'.length);
    });
  }

  static bool isBlagajnik(List<String> userRoles) {
    // Blagajnik (uključujući blagajnikSARTR...) - admin/superadmin imaju veće ovlasti ali mogu pristupiti blagajničkim funkcijama
    return userRoles.any((r) {
      final role = r.trim().toLowerCase();
      return role == blagajnik.toLowerCase() || (role.startsWith('blagajnik') && role.length > 'blagajnik'.length);
    });
  }

  static bool isKorisnik(List<String> userRoles) {
    // Provjeri da li ima samo Korisnik ulogu (bez Admin/Blagajnik/SuperAdmin)
    return hasRole(userRoles, korisnik) && 
           !isSuperAdmin(userRoles) && 
           !isAdmin(userRoles) && 
           !isBlagajnik(userRoles);
  }

  static String getRoleDisplayName(String role) {
    final roleMap = {
      superAdmin: 'Superadministrator',
      admin: 'Administrator institucije',
      blagajnik: 'Blagajnik institucije',
      korisnik: 'Korisnik',
      // Backward compatibility sa starim ulogama
      'superadmin': 'Superadministrator',
      'admin': 'Administrator institucije',
      'blagajnik': 'Blagajnik institucije',
      'korisnik': 'Korisnik',
    };
    
    final normalized = role.trim();
    final lower = normalized.toLowerCase();
    // Institucijske uloge (npr. adminNPS, blagajnikKT) moraju jasno prikazati instituciju
    String? codeFromRole(String prefix) {
      if (!lower.startsWith(prefix) || normalized.length <= prefix.length) return null;
      final code = normalized.substring(prefix.length).trim();
      return code.isEmpty ? null : code.toUpperCase();
    }

    final adminCode = codeFromRole('admin');
    if (adminCode != null) return 'Administrator institucije ($adminCode)';
    final blagajnikCode = codeFromRole('blagajnik');
    if (blagajnikCode != null) return 'Blagajnik institucije ($blagajnikCode)';

    return roleMap[normalized] ?? roleMap[lower] ?? role;
  }

  /// Vraća kod institucije iz naziv-rolе (npr. "adminNPS" -> "NPS").
  /// Korisno za filtriranje dostupnih rola kod admina institucije.
  static String? tryGetInstitutionCodeFromRoleName(String role) {
    final normalized = role.trim();
    final lower = normalized.toLowerCase();
    if (lower.startsWith('admin') && normalized.length > 'admin'.length) {
      final code = normalized.substring('admin'.length).trim();
      return code.isEmpty ? null : code.toUpperCase();
    }
    if (lower.startsWith('blagajnik') && normalized.length > 'blagajnik'.length) {
      final code = normalized.substring('blagajnik'.length).trim();
      return code.isEmpty ? null : code.toUpperCase();
    }
    return null;
  }

  static int? tryGetInstitutionIdFromRoles(List<String> userRoles) {
    String? codeFromRole(String prefix) {
      final match = userRoles
          .map((r) => r.trim())
          .firstWhere(
            (r) => r.toLowerCase().startsWith(prefix) && r.length > prefix.length,
            orElse: () => '',
          );
      if (match.isEmpty) return null;
      return match.substring(prefix.length).toUpperCase();
    }

    final code = codeFromRole('admin') ?? codeFromRole('blagajnik');
    if (code == null) return null;
    return _institutionCodeToId[code];
  }
  
  // Helper metoda za provjeru da li korisnik ima pristup određenoj funkcionalnosti
  static bool canAccessAdminFeatures(List<String> userRoles) {
    return isSuperAdmin(userRoles) || isAdmin(userRoles);
  }
  
  static bool canAccessBlagajnikFeatures(List<String> userRoles) {
    return isSuperAdmin(userRoles) || isAdmin(userRoles) || isBlagajnik(userRoles);
  }
  
  static bool canAccessUserFeatures(List<String> userRoles) {
    // Svi korisnici mogu pristupiti korisničkim funkcionalnostima
    return true;
  }
}





