class PopularityReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<ShowPopularity> mostPopularShows;
  final List<GenrePopularity> mostPopularGenres;
  final List<InstitutionPopularity> mostPopularInstitutions;

  PopularityReport({
    required this.startDate,
    required this.endDate,
    required this.mostPopularShows,
    required this.mostPopularGenres,
    required this.mostPopularInstitutions,
  });

  factory PopularityReport.fromJson(Map<String, dynamic> json) {
    return PopularityReport(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      mostPopularShows: (json['mostPopularShows'] as List<dynamic>?)
          ?.map((s) => ShowPopularity.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      mostPopularGenres: (json['mostPopularGenres'] as List<dynamic>?)
          ?.map((g) => GenrePopularity.fromJson(g as Map<String, dynamic>))
          .toList() ?? [],
      mostPopularInstitutions: (json['mostPopularInstitutions'] as List<dynamic>?)
          ?.map((i) => InstitutionPopularity.fromJson(i as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class ShowPopularity {
  final int showId;
  final String showTitle;
  final int ticketsSold;
  final int reviewsCount;
  final double? averageRating;
  final double revenue;

  ShowPopularity({
    required this.showId,
    required this.showTitle,
    required this.ticketsSold,
    required this.reviewsCount,
    this.averageRating,
    required this.revenue,
  });

  factory ShowPopularity.fromJson(Map<String, dynamic> json) {
    return ShowPopularity(
      showId: json['showId'] as int,
      showTitle: json['showTitle'] as String,
      ticketsSold: json['ticketsSold'] as int,
      reviewsCount: json['reviewsCount'] as int,
      averageRating: json['averageRating'] != null 
          ? (json['averageRating'] as num).toDouble() 
          : null,
      revenue: (json['revenue'] as num).toDouble(),
    );
  }
}

class GenrePopularity {
  final int genreId;
  final String genreName;
  final int showsCount;
  final int ticketsSold;
  final double revenue;

  GenrePopularity({
    required this.genreId,
    required this.genreName,
    required this.showsCount,
    required this.ticketsSold,
    required this.revenue,
  });

  factory GenrePopularity.fromJson(Map<String, dynamic> json) {
    return GenrePopularity(
      genreId: json['genreId'] as int,
      genreName: json['genreName'] as String,
      showsCount: json['showsCount'] as int,
      ticketsSold: json['ticketsSold'] as int,
      revenue: (json['revenue'] as num).toDouble(),
    );
  }
}

class InstitutionPopularity {
  final int institutionId;
  final String institutionName;
  final int showsCount;
  final int ticketsSold;
  final double revenue;

  InstitutionPopularity({
    required this.institutionId,
    required this.institutionName,
    required this.showsCount,
    required this.ticketsSold,
    required this.revenue,
  });

  factory InstitutionPopularity.fromJson(Map<String, dynamic> json) {
    return InstitutionPopularity(
      institutionId: json['institutionId'] as int,
      institutionName: json['institutionName'] as String,
      showsCount: json['showsCount'] as int,
      ticketsSold: json['ticketsSold'] as int,
      revenue: (json['revenue'] as num).toDouble(),
    );
  }
}
