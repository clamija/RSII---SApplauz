class UpdateUserRolesRequest {
  final List<String> roles;

  UpdateUserRolesRequest({
    required this.roles,
  });

  Map<String, dynamic> toJson() {
    return {
      'roles': roles,
    };
  }
}


