import 'user.dart';

class LoginResponse {
  final String token;
  final DateTime expires;
  final User user;

  LoginResponse({
    required this.token,
    required this.expires,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      expires: DateTime.parse(json['expires'] as String),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}






