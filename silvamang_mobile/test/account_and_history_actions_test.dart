import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/core/services/api_client.dart';
import 'package:silvamang_mobile/core/services/local_storage_service.dart';
import 'package:silvamang_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:silvamang_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:silvamang_mobile/features/capture/data/repositories/scan_image_repository.dart';
import 'package:silvamang_mobile/features/records/data/repositories/scan_record_repository.dart';
import 'package:silvamang_mobile/features/records/presentation/controllers/records_controller.dart';

class TestStorage extends Fake implements LocalStorageService {
  String? token;
  @override
  Future<void> saveToken(String value) async {
    token = value;
  }

  @override
  Future<void> saveUserJson(String value) async {}
  @override
  Future<void> clearAuth() async {
    token = null;
  }
}

class TestApi extends Fake implements ApiClient {
  bool failDelete = false;
  bool failRegistration = false;
  String? deleted;
  @override
  Future<Response<T>> post<T>(String path, {Object? data}) async {
    if (failRegistration) throw const ApiException('Registration failed');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'token': 'server-token',
                'user': {'id': 1, 'name': 'Test', 'email': 'test@example.com'},
              }
              as T,
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: path),
    data:
        {
              'data': [
                {'id': 7, 'record_code': 'TEST-7'},
              ],
            }
            as T,
  );
  @override
  Future<Response<T>> delete<T>(String path) async {
    if (failDelete) throw const ApiException('Offline');
    deleted = path;
    return Response<T>(requestOptions: RequestOptions(path: path));
  }
}

class TestImages extends Fake implements ScanImageRepository {}

void main() {
  test(
    'registration leaves no authenticated session; login still saves one',
    () async {
      final api = TestApi();
      final storage = TestStorage();
      final repository = AuthRepository(apiClient: api, storage: storage);
      final controller = AuthController(
        repository: repository,
        storage: storage,
      );
      final states = <AuthState>[];
      controller.addListener(states.add);
      expect(
        await controller.register(
          'Test',
          'test@example.com',
          'password123',
          'password123',
        ),
        isTrue,
      );
      expect(storage.token, isNull);
      expect(states.last.isAuthenticated, isFalse);
      expect(await controller.login('test@example.com', 'password123'), isTrue);
      expect(storage.token, 'server-token');
      expect(states.last.isAuthenticated, isTrue);
      controller.dispose();
    },
  );
  test('registration failure is reported without signing in', () async {
    final storage = TestStorage();
    final controller = AuthController(
      repository: AuthRepository(
        apiClient: TestApi()..failRegistration = true,
        storage: storage,
      ),
      storage: storage,
    );
    expect(
      await controller.register(
        'Test',
        'test@example.com',
        'password123',
        'password123',
      ),
      isFalse,
    );
    expect(storage.token, isNull);
    controller.dispose();
  });
  test(
    'history deletion removes a record only after the server accepts it',
    () async {
      final api = TestApi();
      final controller = RecordsController(
        repository: ScanRecordRepository(
          apiClient: api,
          scanImageRepository: TestImages(),
        ),
      );
      final states = <RecordsState>[];
      controller.addListener(states.add);
      await controller.loadRecords();
      expect(states.last.records.length, 1);
      api.failDelete = true;
      await expectLater(
        controller.deleteRecord('7'),
        throwsA(isA<ApiException>()),
      );
      expect(states.last.records.length, 1);
      api.failDelete = false;
      await controller.deleteRecord('7');
      expect(api.deleted, '/scan-records/7');
      expect(states.last.records, isEmpty);
      controller.dispose();
    },
  );
}
