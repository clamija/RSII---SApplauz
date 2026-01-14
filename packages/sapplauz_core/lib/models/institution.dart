class Institution {
  final int id;
  final String name;
  final String? description;
  final String? address;
  final int capacity;
  final String? imagePath;
  final String? resolvedImagePath;
  final String? website;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int showsCount;

  Institution({
    required this.id,
    required this.name,
    this.description,
    this.address,
    required this.capacity,
    this.imagePath,
    this.resolvedImagePath,
    this.website,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    required this.showsCount,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      capacity: json['capacity'] as int? ?? 0,
      imagePath: json['imagePath'] as String?,
      resolvedImagePath: json['resolvedImagePath'] as String?,
      website: json['website'] as String?,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
      showsCount: json['showsCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'capacity': capacity,
      'imagePath': imagePath,
      'resolvedImagePath': resolvedImagePath,
      'website': website,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'showsCount': showsCount,
    };
  }
}






