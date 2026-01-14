import 'genre.dart';
import 'institution.dart';

class Show {
  final int id;
  final String title;
  final String? description;
  final int durationMinutes;
  final int institutionId;
  final String institutionName;
  final int genreId;
  final String genreName;
  final String? imagePath;
  final String? resolvedImagePath;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? averageRating;
  final int reviewsCount;
  final int performancesCount;

  Show({
    required this.id,
    required this.title,
    this.description,
    required this.durationMinutes,
    required this.institutionId,
    required this.institutionName,
    required this.genreId,
    required this.genreName,
    this.imagePath,
    this.resolvedImagePath,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.averageRating,
    required this.reviewsCount,
    required this.performancesCount,
  });

  factory Show.fromJson(Map<String, dynamic> json) {
    return Show(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      durationMinutes: json['durationMinutes'] as int,
      institutionId: json['institutionId'] as int,
      institutionName: json['institutionName'] as String,
      genreId: json['genreId'] as int,
      genreName: json['genreName'] as String,
      imagePath: json['imagePath'] as String?,
      resolvedImagePath: json['resolvedImagePath'] as String?,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
      averageRating: json['averageRating'] != null 
          ? (json['averageRating'] as num).toDouble() 
          : null,
      reviewsCount: json['reviewsCount'] as int? ?? 0,
      performancesCount: json['performancesCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'institutionId': institutionId,
      'institutionName': institutionName,
      'genreId': genreId,
      'genreName': genreName,
      'imagePath': imagePath,
      'resolvedImagePath': resolvedImagePath,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'averageRating': averageRating,
      'reviewsCount': reviewsCount,
      'performancesCount': performancesCount,
    };
  }

  String get durationFormatted {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  String get genresString => genreName;
  
  // Helper getter za backward compatibility - vraća listu sa jednim žanrom
  List<Genre> get genres => [Genre(id: genreId, name: genreName, createdAt: createdAt)];
}






