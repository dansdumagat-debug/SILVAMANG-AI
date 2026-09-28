import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/core/config/api_config.dart';

void main() {
  group('ApiConfig.normalizeBaseUrl', () {
    test('uses the production API when no URL is configured', () {
      expect(ApiConfig.normalizeBaseUrl(null), ApiConfig.defaultBaseUrl);
    });

    test('adds one api suffix and removes trailing slashes', () {
      expect(
        ApiConfig.normalizeBaseUrl(
          'https://silvamangai.online///',
        ),
        ApiConfig.defaultBaseUrl,
      );
      expect(
        ApiConfig.normalizeBaseUrl(
          'https://silvamangai.online/api/api/',
        ),
        ApiConfig.defaultBaseUrl,
      );
    });

    test('repairs a Markdown-wrapped URL copied into dart-define', () {
      expect(
        ApiConfig.normalizeBaseUrl(
          '[Production API](https://silvamangai.online/api)',
        ),
        ApiConfig.defaultBaseUrl,
      );
    });

    test('rejects invalid URLs', () {
      expect(ApiConfig.normalizeBaseUrl('not-a-url'), ApiConfig.defaultBaseUrl);
    });
  });
}
