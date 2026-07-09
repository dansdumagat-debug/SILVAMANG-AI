import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/local_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      repository: ref.watch(authRepositoryProvider),
      storage: LocalStorageService.instance,
    );
  },
);

class AuthState {
  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.errorMessage,
  });

  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated =>
      token != null && token!.isNotEmpty && user != null;

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      token: clearToken ? null : token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController({required this.repository, required this.storage})
    : super(const AuthState());

  final AuthRepository repository;
  final LocalStorageService storage;

  Future<bool> checkAuthStatus() async {
    final token = storage.getToken();
    final cachedUser = _cachedUser();
    if (token == null || token.isEmpty) {
      state = const AuthState();
      return false;
    }

    state = AuthState(user: cachedUser, token: token, isLoading: true);
    final user = await repository.me();
    if (user == null) {
      state = const AuthState();
      return false;
    }

    state = AuthState(user: user, token: token);
    return true;
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final auth = await repository.login(email: email, password: password);
      state = AuthState(user: auth.user, token: auth.token);
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final auth = await repository.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      state = AuthState(user: auth.user, token: auth.token);
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await repository.logout();
    } finally {
      state = const AuthState();
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  UserModel? _cachedUser() {
    final userJson = storage.getUserJson();
    if (userJson == null || userJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(userJson);
      if (decoded is Map<String, dynamic>) {
        return UserModel.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
