import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImageHelper {
  static const String defaultImage = '/images/default.png';
  
  // Base URL za slike - koristi istu logiku kao ApiService
  // 10.0.2.2 za Android Emulator, localhost za ostale platforme
  // Port 5000 (isti kao u Docker-u)
  // Nema /api prefiks jer se slike služe direktno iz wwwroot/images/
  static String get baseUrl {
    // Provjeri da li je platforma Android
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    }
    // Za Windows, iOS, Web koristi localhost
    return 'http://localhost:5000';
  }

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
