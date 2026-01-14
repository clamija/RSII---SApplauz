import 'order.dart';

class OrderListResponse {
  final List<Order> orders;
  final int totalCount;
  final int pageNumber;
  final int pageSize;
  final int totalPages;

  OrderListResponse({
    required this.orders,
    required this.totalCount,
    required this.pageNumber,
    required this.pageSize,
    required this.totalPages,
  });

  factory OrderListResponse.fromJson(Map<String, dynamic> json) {
    final pageSize = json['pageSize'] as int;
    final totalCount = json['totalCount'] as int;
    final totalPages = pageSize > 0 
        ? ((totalCount + pageSize - 1) / pageSize).ceil() 
        : 0;
    
    return OrderListResponse(
      orders: (json['orders'] as List<dynamic>)
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList(),
      totalCount: totalCount,
      pageNumber: json['pageNumber'] as int,
      pageSize: pageSize,
      totalPages: json['totalPages'] as int? ?? totalPages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orders': orders.map((o) => o.toJson()).toList(),
      'totalCount': totalCount,
      'pageNumber': pageNumber,
      'pageSize': pageSize,
      'totalPages': totalPages,
    };
  }
}






