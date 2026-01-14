import 'user.dart';

class RegisterResponse {
  final User user;
  final String message;

  RegisterResponse({
    required this.user,
    required this.message,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      message: json['message'] as String? ?? '',
    );
  }
}
