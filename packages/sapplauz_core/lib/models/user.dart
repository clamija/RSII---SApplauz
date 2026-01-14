class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final List<String> roles;
  final int? institutionId; // null za SuperAdmin i Korisnik, specific ID za Admin i Blagajnik

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.roles,
    this.institutionId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      roles: List<String>.from(json['roles'] as List),
      institutionId: json['institutionId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'roles': roles,
      'institutionId': institutionId,
    };
  }

  String get fullName => '$firstName $lastName';
}






