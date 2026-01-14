import 'package:flutter_test/flutter_test.dart';
import 'package:sapplauz_mobile/models/user.dart';
import 'package:sapplauz_mobile/models/login_response.dart';

void main() {
  group('User Model Tests', () {
    test('User should parse from JSON correctly', () {
      final json = {
        'id': '123',
        'firstName': 'Test',
        'lastName': 'User',
        'email': 'test@sapplauz.ba',
        'roles': ['User'],
      };

      final user = User.fromJson(json);

      expect(user.id, '123');
      expect(user.firstName, 'Test');
      expect(user.lastName, 'User');
      expect(user.email, 'test@sapplauz.ba');
      expect(user.roles, ['User']);
      expect(user.fullName, 'Test User');
    });

    test('User should convert to JSON correctly', () {
      final user = User(
        id: '123',
        firstName: 'Test',
        lastName: 'User',
        email: 'test@sapplauz.ba',
        roles: ['User'],
      );

      final json = user.toJson();

      expect(json['id'], '123');
      expect(json['firstName'], 'Test');
      expect(json['lastName'], 'User');
      expect(json['email'], 'test@sapplauz.ba');
      expect(json['roles'], ['User']);
    });
  });
}






