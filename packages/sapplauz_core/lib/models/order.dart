import 'order_item.dart';

class Order {
  final int id;
  final String userId;
  final String userName;
  final int? institutionId;
  final String institutionName;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<OrderItem> orderItems;

  Order({
    required this.id,
    required this.userId,
    required this.userName,
    required this.institutionId,
    required this.institutionName,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.orderItems,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: _asInt(json['id']),
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      institutionId: json['institutionId'] != null ? _asInt(json['institutionId']) : null,
      institutionName: json['institutionName']?.toString() ?? 'Nepoznata institucija',
      totalAmount: _asDouble(json['totalAmount']),
      status: json['status']?.toString() ?? '',
      createdAt: _asDate(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? _asDate(json['updatedAt']) : null,
      orderItems: (json['orderItems'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'institutionId': institutionId,
      'institutionName': institutionName,
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'orderItems': orderItems.map((item) => item.toJson()).toList(),
    };
  }

  String get formattedTotalAmount => '${totalAmount.toStringAsFixed(2)} KM';

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Na čekanju';
      case 'paid':
        return 'Plaćeno';
      case 'refunded':
        return 'Refundirano';
      default:
        return status;
    }
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






