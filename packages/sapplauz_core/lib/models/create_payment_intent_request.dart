class CreatePaymentIntentRequest {
  final int orderId;

  CreatePaymentIntentRequest({required this.orderId});

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
    };
  }
}



