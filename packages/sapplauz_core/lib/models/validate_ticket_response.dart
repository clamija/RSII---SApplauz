import 'ticket.dart';

class ValidateTicketResponse {
  final bool isValid;
  final String message;
  final Ticket? ticket;

  ValidateTicketResponse({
    required this.isValid,
    required this.message,
    this.ticket,
  });

  factory ValidateTicketResponse.fromJson(Map<String, dynamic> json) {
    // Backend može vratiti direktno {isValid,message,ticket} ili wrapper {data: {...}, message: "..."}.
    final dynamic inner = json['data'] ?? json;
    final Map<String, dynamic> data =
        inner is Map<String, dynamic> ? inner : Map<String, dynamic>.from(inner as Map);

    final dynamic msg = json['message'] ?? data['message'] ?? '';
    return ValidateTicketResponse(
      isValid: (data['isValid'] as bool?) ?? false,
      message: msg.toString(),
      ticket: data['ticket'] != null
          ? Ticket.fromJson(Map<String, dynamic>.from(data['ticket'] as Map))
          : null,
    );
  }
}



