class ValidateTicketRequest {
  final String qrCode;

  ValidateTicketRequest({required this.qrCode});

  Map<String, dynamic> toJson() {
    return {
      'qrCode': qrCode,
    };
  }
}



