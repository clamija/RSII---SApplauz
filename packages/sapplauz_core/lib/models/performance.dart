class Performance {
  final int id;
  final int showId;
  final String showTitle;
  final DateTime startTime;
  final double price;
  final int availableSeats;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isSoldOut;
  final bool isAlmostSoldOut;
  final String? status; // "Rasprodano", "Posljednja mjesta", "Dostupno", "Trenutno se izvodi"
  final String? statusColor; // "red", "orange", "green", "blue"

  Performance({
    required this.id,
    required this.showId,
    required this.showTitle,
    required this.startTime,
    required this.price,
    required this.availableSeats,
    required this.createdAt,
    this.updatedAt,
    required this.isSoldOut,
    required this.isAlmostSoldOut,
    this.status,
    this.statusColor,
  });

  factory Performance.fromJson(Map<String, dynamic> json) {
    // Backend računa IsSoldOut i IsAlmostSoldOut automatski
    final availableSeats = _asInt(json['availableSeats']);
    final isSoldOut = availableSeats == 0;
    final isAlmostSoldOut = availableSeats > 0 && availableSeats <= 5;
    
    return Performance(
      id: _asInt(json['id']),
      showId: _asInt(json['showId']),
      showTitle: json['showTitle']?.toString() ?? 'Nepoznata predstava',
      startTime: _asDate(json['startTime']),
      price: _asDouble(json['price']),
      availableSeats: availableSeats,
      createdAt: _asDate(json['createdAt']),
      updatedAt: json['updatedAt'] != null 
          ? _asDate(json['updatedAt'])
          : null,
      isSoldOut: json['isSoldOut'] is bool ? json['isSoldOut'] as bool : isSoldOut,
      isAlmostSoldOut: json['isAlmostSoldOut'] is bool ? json['isAlmostSoldOut'] as bool : isAlmostSoldOut,
      status: json['status']?.toString(),
      statusColor: json['statusColor']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'showId': showId,
      'showTitle': showTitle,
      'startTime': startTime.toIso8601String(),
      'price': price,
      'availableSeats': availableSeats,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isSoldOut': isSoldOut,
      'isAlmostSoldOut': isAlmostSoldOut,
      'status': status,
      'statusColor': statusColor,
    };
  }

  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Maj', 'Jun', 
                    'Jul', 'Avg', 'Sep', 'Okt', 'Nov', 'Dec'];
    return '${startTime.day}. ${months[startTime.month - 1]} ${startTime.year}';
  }

  String get formattedTime {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedPrice => '${price.toStringAsFixed(2)} KM';

  // Provjerava da li je termin trenutno aktivan (između startTime i startTime + durationMinutes)
  // Pretpostavljamo da predstava traje oko 90 minuta ako nije specificirano
  bool isCurrentlyShowing([int durationMinutes = 90]) {
    final now = DateTime.now();
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}






