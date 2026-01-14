class CreateOrderRequest {
  final int institutionId;
  final List<OrderItemRequest> orderItems;

  CreateOrderRequest({
    required this.institutionId,
    required this.orderItems,
  });

  Map<String, dynamic> toJson() {
    return {
      'institutionId': institutionId,
      'orderItems': orderItems.map((item) => item.toJson()).toList(),
    };
  }
}

class OrderItemRequest {
  final int performanceId;
  final int quantity;

  OrderItemRequest({
    required this.performanceId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'performanceId': performanceId,
      'quantity': quantity,
    };
  }
}






