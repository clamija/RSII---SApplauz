class Ticket {
  final int id;
  final int orderId;
  final int orderItemId;
  final String qrCode;
  final String status;
  final DateTime? scannedAt;
  final DateTime createdAt;
  final String userFullName;
  final int institutionId;
  final String showTitle;
  final DateTime performanceStartTime;
  final String institutionName;

  Ticket({
    required this.id,
    required this.orderId,
    required this.orderItemId,
    required this.qrCode,
    required this.status,
    this.scannedAt,
    required this.createdAt,
    required this.userFullName,
    required this.institutionId,
    required this.showTitle,
    required this.performanceStartTime,
    required this.institutionName,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderId: (json['orderId'] as num?)?.toInt() ?? 0,
      orderItemId: (json['orderItemId'] as num?)?.toInt() ?? 0,
      qrCode: json['qrCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      scannedAt: json['scannedAt'] != null 
          ? DateTime.tryParse(json['scannedAt']?.toString() ?? '') 
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      userFullName: json['userFullName']?.toString() ?? '',
      institutionId: (json['institutionId'] as num?)?.toInt() ?? 0,
      showTitle: json['showTitle']?.toString() ?? '',
      performanceStartTime: DateTime.tryParse(json['performanceStartTime']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      institutionName: json['institutionName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'orderItemId': orderItemId,
      'qrCode': qrCode,
      'status': status,
      'scannedAt': scannedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'userFullName': userFullName,
      'institutionId': institutionId,
      'showTitle': showTitle,
      'performanceStartTime': performanceStartTime.toIso8601String(),
      'institutionName': institutionName,
    };
  }

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'notscanned':
        return 'Nije skenirana';
      case 'scanned':
        return 'Skenirana';
      case 'invalid':
        return 'Nevažeća';
      case 'refunded':
        return 'Refundirana';
      default:
        return status;
    }
  }

  bool get isRefunded => status.toLowerCase() == 'refunded';
  bool get isValid {
    final s = status.toLowerCase();
    return s != 'invalid' && s != 'refunded';
  }
  bool get isScanned => status.toLowerCase() == 'scanned';

  String get formattedDate {
    final local = performanceStartTime.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Maj', 'Jun',
                    'Jul', 'Avg', 'Sep', 'Okt', 'Nov', 'Dec'];
    return '${local.day}. ${months[local.month - 1]} ${local.year}';
  }

  String get formattedTime {
    final local = performanceStartTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}






