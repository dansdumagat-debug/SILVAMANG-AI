import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  const ApiConfig._();

  static const defaultBaseUrl =
      'https://silvamangai.online/api';

  static String get baseUrl {
    const dartDefinedUrl = String.fromEnvironment('API_BASE_URL');
    if (dartDefinedUrl.trim().isNotEmpty) {
      return normalizeBaseUrl(dartDefinedUrl);
    }

    return normalizeBaseUrl(dotenv.env['API_BASE_URL']);
  }

  static String normalizeBaseUrl(String? rawUrl) {
    var value = rawUrl?.trim() ?? '';
    if (value.isEmpty) {
      return defaultBaseUrl;
    }

    final markdownMatch = RegExp(
      r'^\[[^\]]+\]\((https?://[^)]+)\)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (markdownMatch != null) {
      value = markdownMatch.group(1) ?? value;
    }

    value = value.replaceFirst(RegExp(r'/+$'), '');
    value = value.replaceFirst(
      RegExp(r'(?:/api)+$', caseSensitive: false),
      '/api',
    );
    if (!value.toLowerCase().endsWith('/api')) {
      value = '$value/api';
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return defaultBaseUrl;
    }

    return uri.toString().replaceFirst(RegExp(r'/+$'), '');
  }
}
