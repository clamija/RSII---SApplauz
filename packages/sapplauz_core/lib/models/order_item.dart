import 'ticket.dart';

class OrderItem {
  final int id;
  final int orderId;
  final int performanceId;
  final String performanceShowTitle;
  final DateTime performanceStartTime;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final List<Ticket> tickets;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.performanceId,
    required this.performanceShowTitle,
    required this.performanceStartTime,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.tickets,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: _asInt(json['id']),
      orderId: _asInt(json['orderId']),
      performanceId: _asInt(json['performanceId']),
      performanceShowTitle: json['performanceShowTitle']?.toString() ?? 'Nepoznata predstava',
      performanceStartTime: _asDate(json['performanceStartTime']),
      quantity: _asInt(json['quantity']),
      unitPrice: _asDouble(json['unitPrice']),
      subtotal: _asDouble(json['subtotal']),
      tickets: (json['tickets'] as List<dynamic>?)
              ?.map((t) => Ticket.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'performanceId': performanceId,
      'performanceShowTitle': performanceShowTitle,
      'performanceStartTime': performanceStartTime.toIso8601String(),
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      'tickets': tickets.map((t) => t.toJson()).toList(),
    };
  }

  String get formattedSubtotal => '${subtotal.toStringAsFixed(2)} KM';
  String get formattedUnitPrice => '${unitPrice.toStringAsFixed(2)} KM';

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






