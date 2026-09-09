import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConnectivityService {
  const ConnectivityService();

  Future<dynamic> checkConnection() {
    return Connectivity().checkConnectivity();
  }

  Future<bool> isOnline() async {
    return _canReachApi();
  }

  Future<bool> hasNetworkConnection() async {
    final result = await checkConnection();

    if (result is Iterable<ConnectivityResult>) {
      return result.any((status) => status != ConnectivityResult.none);
    }

    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }

    return false;
  }

  Stream<bool> watchOnlineStatus() {
    return Connectivity().onConnectivityChanged
        .asyncMap((_) => isOnline())
        .distinct();
  }

  Future<bool> _canReachApi() async {
    final baseUrl = _apiBaseUrl();
    final healthUrl = '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/health';

    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      ).getUri(Uri.parse(healthUrl));

      final statusCode = response.statusCode ?? 0;
      return statusCode >= 200 && statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static String _apiBaseUrl() {
    const dartDefineBaseUrl = String.fromEnvironment('API_BASE_URL');
    final definedUrl = dartDefineBaseUrl.trim();
    if (definedUrl.isNotEmpty) {
      return definedUrl;
    }

    final envUrl = dotenv.env['API_BASE_URL']?.trim();
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    return 'http://10.0.2.2:8000/api';
  }
}
