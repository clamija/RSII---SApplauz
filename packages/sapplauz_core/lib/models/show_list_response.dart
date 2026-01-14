import 'show.dart';

class ShowListResponse {
  final List<Show> shows;
  final int totalCount;
  final int pageNumber;
  final int pageSize;
  final int totalPages;

  ShowListResponse({
    required this.shows,
    required this.totalCount,
    required this.pageNumber,
    required this.pageSize,
    required this.totalPages,
  });

  factory ShowListResponse.fromJson(Map<String, dynamic> json) {
    final pageSize = json['pageSize'] as int;
    final totalCount = json['totalCount'] as int;
    final totalPages = pageSize > 0 
        ? ((totalCount + pageSize - 1) / pageSize).ceil() 
        : 0;
    
    return ShowListResponse(
      shows: (json['shows'] as List<dynamic>)
          .map((s) => Show.fromJson(s as Map<String, dynamic>))
          .toList(),
      totalCount: totalCount,
      pageNumber: json['pageNumber'] as int,
      pageSize: pageSize,
      totalPages: json['totalPages'] as int? ?? totalPages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shows': shows.map((s) => s.toJson()).toList(),
      'totalCount': totalCount,
      'pageNumber': pageNumber,
      'pageSize': pageSize,
      'totalPages': totalPages,
    };
  }
}






