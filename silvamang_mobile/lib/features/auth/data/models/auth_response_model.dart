import 'user_model.dart';

class AuthResponseModel {
  const AuthResponseModel({
    required this.token,
    required this.user,
    this.roles = const [],
  });

  final String token;
  final UserModel user;
  final List<String> roles;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final userJson = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final dataRoles = UserModel.parseRoles(data['roles']);
    final userRoles = UserModel.parseRoles(userJson['roles']);
    final roles = dataRoles.isNotEmpty ? dataRoles : userRoles;

    return AuthResponseModel(
      token: (data['token'] ?? '').toString(),
      user: UserModel.fromJson({...userJson, 'roles': roles}),
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() {
    return {'token': token, 'user': user.toJson(), 'roles': roles};
  }
}
