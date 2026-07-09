import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/local_storage_service.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ApiClient.instance,
    storage: LocalStorageService.instance,
  );
});

class AuthRepository {
  const AuthRepository({required this.apiClient, required this.storage});

  final ApiClient apiClient;
  final LocalStorageService storage;

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/login',
      data: {'email': email, 'password': password},
    );

    final auth = AuthResponseModel.fromJson(response.data ?? {});
    await _saveAuth(auth);
    return auth;
  }

  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    final auth = AuthResponseModel.fromJson(response.data ?? {});
    await _saveAuth(auth);
    return auth;
  }

  Future<UserModel?> me() async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>('/me');
      final data = response.data ?? {};
      final userData = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;
      final userJson = userData['user'] is Map<String, dynamic>
          ? userData['user'] as Map<String, dynamic>
          : userData;
      final roles = UserModel.parseRoles(
        userData['roles'] ?? userJson['roles'],
      );
      final user = UserModel.fromJson({...userJson, 'roles': roles});
      await storage.saveUserJson(jsonEncode(user.toJson()));
      return user;
    } on ApiException {
      await storage.clearAuth();
      return null;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await storage.clearAuth();
      }
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await apiClient.post<Map<String, dynamic>>('/logout');
    } finally {
      await storage.clearAuth();
    }
  }

  Future<void> _saveAuth(AuthResponseModel auth) async {
    await storage.saveToken(auth.token);
    await storage.saveUserJson(jsonEncode(auth.user.toJson()));
  }
}
