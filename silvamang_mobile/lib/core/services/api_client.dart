import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'local_storage_service.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _apiBaseUrl(),
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = LocalStorageService.instance.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  final Dio _dio;

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

    return 'https://silvamang-api-service.onrender.com/api';
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      return await _dio.get<T>(path, queryParameters: query);
    } on DioException catch (error) {
      throw ApiException(
        _messageFrom(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Response<T>> post<T>(String path, {Object? data}) async {
    try {
      return await _dio.post<T>(path, data: data);
    } on DioException catch (error) {
      throw ApiException(
        _messageFrom(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Response<T>> postForm<T>(
    String path, {
    required FormData data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
    } on DioException catch (error) {
      throw ApiException(
        _messageFrom(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Response<Map<String, dynamic>>> classifyImage({
    String? imagePath,
    List<int>? imageBytes,
    String fileName = 'scan.jpg',
    String? imageBase64,
    double? latitude,
    double? longitude,
    String? scanRecordId,
  }) {
    return _postAiImage(
      '/ai/classify',
      imagePath: imagePath,
      imageBytes: imageBytes,
      fileName: fileName,
      imageBase64: imageBase64,
      latitude: latitude,
      longitude: longitude,
      scanRecordId: scanRecordId,
    );
  }

  Future<Response<Map<String, dynamic>>> detectPlantParts({
    String? imagePath,
    List<int>? imageBytes,
    String fileName = 'scan.jpg',
    String? imageBase64,
    double? latitude,
    double? longitude,
    String? scanRecordId,
  }) {
    return _postAiImage(
      '/ai/detect',
      imagePath: imagePath,
      imageBytes: imageBytes,
      fileName: fileName,
      imageBase64: imageBase64,
      latitude: latitude,
      longitude: longitude,
      scanRecordId: scanRecordId,
    );
  }

  Future<Response<Map<String, dynamic>>> segmentPlant({
    String? imagePath,
    List<int>? imageBytes,
    String fileName = 'scan.jpg',
    String? imageBase64,
    double? latitude,
    double? longitude,
    String? scanRecordId,
  }) {
    return _postAiImage(
      '/ai/segment',
      imagePath: imagePath,
      imageBytes: imageBytes,
      fileName: fileName,
      imageBase64: imageBase64,
      latitude: latitude,
      longitude: longitude,
      scanRecordId: scanRecordId,
    );
  }

  Future<Response<Map<String, dynamic>>> measurePlant({
    String? imagePath,
    List<int>? imageBytes,
    String fileName = 'scan.jpg',
    String? imageBase64,
    double? latitude,
    double? longitude,
    String? scanRecordId,
    String? measurementType,
    double? referenceHeightM,
    double? subjectDistanceM,
    double? referenceDistanceM,
    double? subjectPixelSpan,
    double? referencePixelSpan,
  }) {
    return _postAiImage(
      '/ai/measure',
      imagePath: imagePath,
      imageBytes: imageBytes,
      fileName: fileName,
      imageBase64: imageBase64,
      latitude: latitude,
      longitude: longitude,
      scanRecordId: scanRecordId,
      additionalFields: {
        if (measurementType != null && measurementType.trim().isNotEmpty)
          'measurement_type': measurementType.trim(),
        if (referenceHeightM != null)
          'reference_height_m': referenceHeightM.toString(),
        if (subjectDistanceM != null)
          'subject_distance_m': subjectDistanceM.toString(),
        if (referenceDistanceM != null)
          'reference_distance_m': referenceDistanceM.toString(),
        if (subjectPixelSpan != null)
          'subject_pixel_span': subjectPixelSpan.toString(),
        if (referencePixelSpan != null)
          'reference_pixel_span': referencePixelSpan.toString(),
      },
    );
  }

  Future<Response<Map<String, dynamic>>> _postAiImage(
    String path, {
    String? imagePath,
    List<int>? imageBytes,
    required String fileName,
    String? imageBase64,
    double? latitude,
    double? longitude,
    String? scanRecordId,
    Map<String, String> additionalFields = const {},
  }) async {
    final formData = await _aiImageFormData(
      imagePath: imagePath,
      imageBytes: imageBytes,
      fileName: fileName,
      imageBase64: imageBase64,
      latitude: latitude,
      longitude: longitude,
      scanRecordId: scanRecordId,
      additionalFields: additionalFields,
    );

    return postForm<Map<String, dynamic>>(path, data: formData);
  }

  Future<FormData> _aiImageFormData({
    String? imagePath,
    List<int>? imageBytes,
    required String fileName,
    String? imageBase64,
    double? latitude,
    double? longitude,
    String? scanRecordId,
    Map<String, String> additionalFields = const {},
  }) async {
    final formData = FormData();

    for (final field in additionalFields.entries) {
      if (field.value.trim().isNotEmpty) {
        formData.fields.add(MapEntry(field.key, field.value.trim()));
      }
    }

    if (latitude != null) {
      formData.fields.add(MapEntry('latitude', latitude.toString()));
    }
    if (longitude != null) {
      formData.fields.add(MapEntry('longitude', longitude.toString()));
    }
    if (scanRecordId != null) {
      formData.fields.add(MapEntry('scan_record_id', scanRecordId.toString()));
    }
    if (imageBase64 != null && imageBase64.trim().isNotEmpty) {
      formData.fields.add(MapEntry('image_base64', imageBase64.trim()));
    }

    final cleanPath = imagePath?.trim() ?? '';
    if (!kIsWeb && cleanPath.isNotEmpty) {
      try {
        formData.files.add(
          MapEntry(
            'image',
            await MultipartFile.fromFile(cleanPath, filename: fileName),
          ),
        );
        return formData;
      } catch (_) {
        // Fall back to in-memory bytes when the native file path is unavailable.
      }
    }

    if (imageBytes != null && imageBytes.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'image',
          MultipartFile.fromBytes(imageBytes, filename: fileName),
        ),
      );
    }

    return formData;
  }

  Future<Response<T>> put<T>(String path, {Object? data}) async {
    try {
      return await _dio.put<T>(path, data: data);
    } on DioException catch (error) {
      throw ApiException(
        _messageFrom(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Response<T>> delete<T>(String path) async {
    try {
      return await _dio.delete<T>(path);
    } on DioException catch (error) {
      throw ApiException(
        _messageFrom(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  static String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Unable to connect to SILVAMANG AI server.';
  }
}
