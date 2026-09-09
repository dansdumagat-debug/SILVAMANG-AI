import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/api_client.dart';
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
    this.isOfflineSession = false,
    this.errorMessage,
  });

  final UserModel? user;
  final String? token;
  final bool isLoading;
  final bool isOfflineSession;
  final String? errorMessage;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoading,
    bool? isOfflineSession,
    String? errorMessage,
    bool clearUser = false,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      token: clearToken ? null : token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      isOfflineSession: isOfflineSession ?? this.isOfflineSession,
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

    try {
      final user = await repository.me();
      state = AuthState(user: user, token: token);
      return true;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await storage.clearAuth();
        state = const AuthState();
        return false;
      }

      state = AuthState(
        user: cachedUser,
        token: token,
        isOfflineSession: true,
        errorMessage:
            'Offline session active. Your data will sync when connection is restored.',
      );
      return true;
    } catch (_) {
      state = AuthState(
        user: cachedUser,
        token: token,
        isOfflineSession: true,
        errorMessage:
            'Offline session active. Your data will sync when connection is restored.',
      );
      return true;
    }
  }

  Future<void> clearUnauthorizedSession() async {
    await storage.clearAuth();
    state = const AuthState();
  }

  Future<bool> refreshCurrentUser() async {
    if (state.token == null || state.token!.isEmpty) {
      return false;
    }

    try {
      final user = await repository.me();
      state = state.copyWith(user: user, isOfflineSession: false);
      return true;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await clearUnauthorizedSession();
        return false;
      }
      state = state.copyWith(isOfflineSession: true);
      return true;
    }
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
