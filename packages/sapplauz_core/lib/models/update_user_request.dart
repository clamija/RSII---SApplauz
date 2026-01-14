class UpdateUserRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String? currentPassword;
  final String? newPassword;

  UpdateUserRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    this.currentPassword,
    this.newPassword,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
    };
    
    if (currentPassword != null && currentPassword!.isNotEmpty) {
      json['currentPassword'] = currentPassword!;
    }
    
    if (newPassword != null && newPassword!.isNotEmpty) {
      json['newPassword'] = newPassword!;
    }
    
    return json;
  }
}
