class CreateUserRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final List<String> roles;

  CreateUserRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.roles,
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'roles': roles,
    };
  }
}


