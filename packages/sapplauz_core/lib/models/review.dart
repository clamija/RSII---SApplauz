class Review {
  final int id;
  final String userId;
  final String userName;
  final int showId;
  final String showTitle;
  final int rating;
  final String? comment;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.showId,
    required this.showTitle,
    required this.rating,
    this.comment,
    required this.isVisible,
    required this.createdAt,
    this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      showId: json['showId'] as int,
      showTitle: json['showTitle'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      isVisible: json['isVisible'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'showId': showId,
      'showTitle': showTitle,
      'rating': rating,
      'comment': comment,
      'isVisible': isVisible,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class CreateReviewRequest {
  final int showId;
  final int rating;
  final String? comment;

  CreateReviewRequest({
    required this.showId,
    required this.rating,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'showId': showId,
      'rating': rating,
      'comment': comment,
    };
  }
}
