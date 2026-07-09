import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();
  static const _boxName = 'silvamang_local_storage';
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  Box<String>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<void> saveString(String key, String value) async {
    await _box?.put(key, value);
  }

  String? getString(String key) {
    return _box?.get(key);
  }

  Future<void> remove(String key) async {
    await _box?.delete(key);
  }

  Future<void> saveToken(String token) {
    return saveString(_tokenKey, token);
  }

  String? getToken() {
    return getString(_tokenKey);
  }

  Future<void> removeToken() {
    return remove(_tokenKey);
  }

  Future<void> saveUserJson(String json) {
    return saveString(_userKey, json);
  }

  String? getUserJson() {
    return getString(_userKey);
  }

  Future<void> removeUserJson() {
    return remove(_userKey);
  }

  Future<void> clearAuth() async {
    await removeToken();
    await removeUserJson();
  }
}
