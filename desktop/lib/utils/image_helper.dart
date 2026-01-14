class ImageHelper {
  static const String defaultImage = '/images/default.png';
  static const String baseUrl = 'http://localhost:5169';

  /// Vraća URL slike sa fallback logikom:
  /// 1. Ako postoji showImagePath, koristi ga
  /// 2. Ako ne postoji, koristi institutionImagePath
  /// 3. Ako ni to ne postoji, koristi defaultImage
  static String getImageUrl({
    String? imagePath,
    String? institutionImagePath,
    String? defaultImagePath,
  }) {
    final image = imagePath ?? institutionImagePath ?? (defaultImagePath ?? defaultImage);
    
    // Ako je već pun URL, vrati ga
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    
    // Ako počinje sa /, dodaj baseUrl
    if (image.startsWith('/')) {
      return '$baseUrl$image';
    }
    
    // Inače, dodaj baseUrl i /
    return '$baseUrl/$image';
  }

  /// Vraća ResolvedImagePath iz ShowDto ili InstitutionDto
  static String? getResolvedImagePath(Map<String, dynamic>? dto) {
    if (dto == null) return null;
    
    // Provjeri da li postoji resolvedImagePath
    if (dto.containsKey('resolvedImagePath') && dto['resolvedImagePath'] != null) {
      final resolved = dto['resolvedImagePath'] as String;
      if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
        return resolved;
      }
      return '$baseUrl$resolved';
    }
    
    // Fallback na imagePath
    if (dto.containsKey('imagePath') && dto['imagePath'] != null) {
      final imagePath = dto['imagePath'] as String;
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return imagePath;
      }
      return '$baseUrl$imagePath';
    }
    
    return null;
  }
}
