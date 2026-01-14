import 'package:flutter_test/flutter_test.dart';
import 'package:sapplauz_mobile/services/api_service.dart';
import 'package:sapplauz_mobile/models/login_request.dart';

void main() {
  group('ApiService Tests', () {
    test('Login request should create correct JSON', () {
      final request = LoginRequest(
        email: 'test@sapplauz.ba',
        password: 'Test123!',
      );

      final json = request.toJson();

      expect(json['email'], 'test@sapplauz.ba');
      expect(json['password'], 'Test123!');
    });
  });
}






