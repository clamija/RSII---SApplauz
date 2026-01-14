import 'show.dart';

class Recommendation {
  final Show show;
  final double score;
  final String reason;

  Recommendation({
    required this.show,
    required this.score,
    required this.reason,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      show: Show.fromJson(json['show'] as Map<String, dynamic>),
      score: (json['score'] as num).toDouble(),
      reason: json['reason'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'show': show.toJson(),
      'score': score,
      'reason': reason,
    };
  }
}






