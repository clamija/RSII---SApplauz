class CreatePaymentIntentResponse {
  final String clientSecret;
  final String paymentIntentId;
  final String publishableKey;

  CreatePaymentIntentResponse({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.publishableKey,
  });

  factory CreatePaymentIntentResponse.fromJson(Map<String, dynamic> json) {
    return CreatePaymentIntentResponse(
      clientSecret: json['clientSecret']?.toString() ?? '',
      paymentIntentId: json['paymentIntentId']?.toString() ?? '',
      publishableKey: json['publishableKey']?.toString() ?? '',
    );
  }
}



