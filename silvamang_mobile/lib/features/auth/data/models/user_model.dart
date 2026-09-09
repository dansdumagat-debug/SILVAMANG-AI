class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.roles = const [],
  });

  final String id;
  final String name;
  final String email;
  final List<String> roles;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _asString(json['id']),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      roles: parseRoles(json['roles']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'roles': roles};
  }

  static List<String> parseRoles(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((role) {
          if (role is String) {
            return role;
          }
          if (role is Map && role['name'] != null) {
            return role['name'].toString();
          }
          return '';
        })
        .where((role) => role.isNotEmpty)
        .toList();
  }

  static String _asString(Object? value) {
    return value?.toString() ?? '';
  }
}
