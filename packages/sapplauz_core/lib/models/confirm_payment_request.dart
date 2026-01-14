class ConfirmPaymentRequest {
  final int orderId;
  final String paymentIntentId;

  ConfirmPaymentRequest({
    required this.orderId,
    required this.paymentIntentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'paymentIntentId': paymentIntentId,
    };
  }
}



