import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as image_lib;

import '../models/mock_ai_prediction_response.dart';

class OfflinePredictionException implements Exception {
  const OfflinePredictionException(this.reason, [this.detail]);

  final String reason;
  final String? detail;

  @override
  String toString() => detail == null ? reason : '$reason $detail';
}

class OfflineModelDiagnosticResult {
  const OfflineModelDiagnosticResult({
    required this.platformSupported,
    required this.classOrderLoaded,
    required this.classCount,
    required this.singleModelAssetLoaded,
    required this.pairedModelAssetLoaded,
    required this.pairedDataAssetLoaded,
    required this.selectedModelAsset,
    required this.selectedModelFileSize,
    required this.sessionCreationAttempted,
    required this.sessionCreationSucceeded,
    required this.dummyInferenceSucceeded,
    this.failureReason,
    this.technicalDetail,
    this.inputNames = const [],
    this.outputNames = const [],
  });

  final bool platformSupported;
  final bool classOrderLoaded;
  final int classCount;
  final bool singleModelAssetLoaded;
  final bool pairedModelAssetLoaded;
  final bool pairedDataAssetLoaded;
  final String selectedModelAsset;
  final int selectedModelFileSize;
  final bool sessionCreationAttempted;
  final bool sessionCreationSucceeded;
  final bool dummyInferenceSucceeded;
  final String? failureReason;
  final String? technicalDetail;
  final List<String> inputNames;
  final List<String> outputNames;

  bool get isReady =>
      platformSupported &&
      classOrderLoaded &&
      classCount > 0 &&
      singleModelAssetLoaded &&
      sessionCreationSucceeded &&
      dummyInferenceSucceeded;
}

class OfflinePredictionService {
  OfflinePredictionService();

  static const _singleModelAssetPath =
      'assets/models/efficientnet_b0_silvamang_single.onnx';
  static const _modelAssetPath = 'assets/models/efficientnet_b0_silvamang.onnx';
  static const _modelDataAssetPath =
      'assets/models/efficientnet_b0_silvamang.onnx.data';
  static const _classOrderAssetPath = 'assets/models/class_order.json';
  static const int _inputSize = 224;
  static const int _resizeSize = 256;
  static const int _inputElementCount = 1 * 3 * _inputSize * _inputSize;
  static const _mean = [0.485, 0.456, 0.406];
  static const _std = [0.229, 0.224, 0.225];

  OrtSession? _session;
  List<String>? _classOrder;
  _SelectedModelAsset? _selectedModel;

  Future<OfflineModelDiagnosticResult> checkOfflineModel() async {
    final platformSupported = _isSupportedPlatform;
    if (!platformSupported) {
      return const OfflineModelDiagnosticResult(
        platformSupported: false,
        classOrderLoaded: false,
        classCount: 0,
        singleModelAssetLoaded: false,
        pairedModelAssetLoaded: false,
        pairedDataAssetLoaded: false,
        selectedModelAsset: '',
        selectedModelFileSize: 0,
        sessionCreationAttempted: false,
        sessionCreationSucceeded: false,
        dummyInferenceSucceeded: false,
        failureReason: 'web_not_supported',
      );
    }

    List<String> classOrder = const [];
    try {
      classOrder = await _loadClassOrder();
    } catch (error) {
      return _diagnosticResult(
        classOrderLoaded: false,
        failureReason: 'class_order_missing',
        technicalDetail: _sanitizeError(error),
      );
    }

    final singleAsset = await _assetInfo(_singleModelAssetPath);
    final pairedAsset = await _assetInfo(_modelAssetPath);
    final pairedDataAsset = await _assetInfo(_modelDataAssetPath);
    final selectedModel = _selectModelAsset(
      singleAsset: singleAsset,
      pairedAsset: pairedAsset,
      pairedDataAsset: pairedDataAsset,
    );

    if (selectedModel == null) {
      return _diagnosticResult(
        classOrderLoaded: true,
        classCount: classOrder.length,
        singleModelAssetLoaded: singleAsset.exists,
        pairedModelAssetLoaded: pairedAsset.exists,
        pairedDataAssetLoaded: pairedDataAsset.exists,
        failureReason: singleAsset.exists
            ? 'model_data_asset_missing'
            : 'model_asset_missing',
      );
    }

    try {
      final session = await _loadSession(selectedModel: selectedModel);
      final inputNames = session.inputNames;
      final outputNames = session.outputNames;
      final inputName = inputNames.isNotEmpty ? inputNames.first : 'input';
      final outputName = outputNames.isNotEmpty ? outputNames.first : null;
      final zeroInput = Float32List(_inputElementCount);
      final inputTensor = await OrtValue.fromList(zeroInput, const [
        1,
        3,
        _inputSize,
        _inputSize,
      ]);
      final outputs = await _runSession(session, inputName, inputTensor);
      final logits = await _flattenOutput(_selectOutput(outputs, outputName));

      return _diagnosticResult(
        classOrderLoaded: true,
        classCount: classOrder.length,
        singleModelAssetLoaded: singleAsset.exists,
        pairedModelAssetLoaded: pairedAsset.exists,
        pairedDataAssetLoaded: pairedDataAsset.exists,
        selectedModelAsset: selectedModel.assetPath,
        selectedModelFileSize: selectedModel.sizeBytes,
        sessionCreationAttempted: true,
        sessionCreationSucceeded: true,
        dummyInferenceSucceeded: logits.isNotEmpty,
        inputNames: inputNames,
        outputNames: outputNames,
        failureReason: logits.isEmpty ? 'output_parse_failed' : null,
      );
    } catch (error) {
      return _diagnosticResult(
        classOrderLoaded: true,
        classCount: classOrder.length,
        singleModelAssetLoaded: singleAsset.exists,
        pairedModelAssetLoaded: pairedAsset.exists,
        pairedDataAssetLoaded: pairedDataAsset.exists,
        selectedModelAsset: selectedModel.assetPath,
        selectedModelFileSize: selectedModel.sizeBytes,
        sessionCreationAttempted: true,
        failureReason: _failureReason(error, 'session_creation_failed'),
        technicalDetail: _sanitizeError(error),
      );
    }
  }

  Future<MockAiPredictionResponse> predict({
    required String imagePath,
    required List<int> previewBytes,
    required List<String> plantParts,
  }) async {
    if (!_isSupportedPlatform) {
      throw const OfflinePredictionException('web_not_supported');
    }

    final selectedImagePath = imagePath.trim();
    if (selectedImagePath.isEmpty || !File(selectedImagePath).existsSync()) {
      throw const OfflinePredictionException('selected_image_missing');
    }

    if (kDebugMode) {
      debugPrint('SILVAMANG AI offline prediction attempted');
      debugPrint('SILVAMANG AI offline image path: $selectedImagePath');
      debugPrint(
        'SILVAMANG AI offline plant part: '
        '${plantParts.isEmpty ? 'leaves' : plantParts.first}',
      );
    }

    final classOrder = await _loadClassOrder();
    final selectedModel = await _prepareModelAsset();
    final session = await _loadSession(selectedModel: selectedModel);
    final inputNames = session.inputNames;
    final outputNames = session.outputNames;
    final inputName = inputNames.isNotEmpty ? inputNames.first : 'input';
    final outputName = outputNames.isNotEmpty ? outputNames.first : null;
    final inputTensorData = await _preprocessImage(
      imagePath: selectedImagePath,
    );

    late final OrtValue inputTensor;
    try {
      inputTensor = await OrtValue.fromList(
        Float32List.fromList(inputTensorData),
        const [1, 3, _inputSize, _inputSize],
      );
    } catch (error) {
      throw OfflinePredictionException(
        'input_tensor_failed',
        _sanitizeError(error),
      );
    }

    late final Map<String, OrtValue> outputs;
    try {
      outputs = await _runSession(session, inputName, inputTensor);
    } catch (error) {
      throw OfflinePredictionException(
        'inference_failed',
        _sanitizeError(error),
      );
    }

    final logits = await _flattenOutput(_selectOutput(outputs, outputName));
    if (logits.isEmpty) {
      throw const OfflinePredictionException(
        'output_parse_failed',
        'Offline model output could not be parsed.',
      );
    }

    final probabilities = _softmax(logits);
    final topPredictions = _topK(probabilities, classOrder, 3);
    if (topPredictions.isEmpty) {
      throw const OfflinePredictionException(
        'output_parse_failed',
        'Offline model output could not be parsed.',
      );
    }

    final normalizedPlantParts = plantParts.isEmpty ? ['leaves'] : plantParts;

    if (kDebugMode) {
      debugPrint(
        'SILVAMANG AI offline top prediction: '
        '${topPredictions.first['scientific_name']}',
      );
      debugPrint('SILVAMANG AI offline input names: $inputNames');
      debugPrint('SILVAMANG AI offline output names: $outputNames');
    }

    return MockAiPredictionResponse.fromJson({
      'mode': 'offline_onnx_efficientnet_b0',
      'source': 'flutter_offline_model',
      'warning': null,
      'model': {
        'name': 'SILVAMANG EfficientNet-B0 Offline',
        'version': 'onnx-offline-0.2.0',
        'type': 'classification',
      },
      'top_prediction': topPredictions.first,
      'predictions': topPredictions,
      'explanation':
          'Prediction generated on-device using the SILVAMANG ONNX EfficientNet-B0 model.',
      'measurement': {
        'height_m': null,
        'canopy_width_m': null,
        'dbh_cm': null,
        'measurement_method': 'not_available_offline',
        'confidence': null,
      },
      'location_hint': {
        'latitude': null,
        'longitude': null,
        'message': 'Offline prediction does not validate location.',
      },
      'received': {'image_count': 1, 'plant_parts': normalizedPlantParts},
    });
  }

  bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<String>> _loadClassOrder() async {
    if (_classOrder != null) {
      return _classOrder!;
    }

    try {
      final classOrderText = await rootBundle.loadString(_classOrderAssetPath);
      final decoded = jsonDecode(classOrderText);
      if (decoded is! List || decoded.isEmpty) {
        throw const FormatException(
          'class_order.json must be a non-empty list.',
        );
      }
      _classOrder = decoded.map((item) => item.toString()).toList();
      return _classOrder!;
    } catch (error) {
      throw OfflinePredictionException(
        'class_order_missing',
        _sanitizeError(error),
      );
    }
  }

  Future<_SelectedModelAsset> _prepareModelAsset() async {
    final singleAsset = await _assetInfo(_singleModelAssetPath);
    final pairedAsset = await _assetInfo(_modelAssetPath);
    final pairedDataAsset = await _assetInfo(_modelDataAssetPath);
    final selectedModel = _selectModelAsset(
      singleAsset: singleAsset,
      pairedAsset: pairedAsset,
      pairedDataAsset: pairedDataAsset,
    );

    if (selectedModel == null) {
      throw OfflinePredictionException(
        singleAsset.exists ? 'model_data_asset_missing' : 'model_asset_missing',
      );
    }

    return selectedModel;
  }

  _SelectedModelAsset? _selectModelAsset({
    required _AssetInfo singleAsset,
    required _AssetInfo pairedAsset,
    required _AssetInfo pairedDataAsset,
  }) {
    if (singleAsset.exists) {
      return _SelectedModelAsset(
        assetPath: singleAsset.assetPath,
        sizeBytes: singleAsset.sizeBytes,
        usesSingleFileMode: true,
      );
    }

    if (pairedAsset.exists && pairedDataAsset.exists) {
      return _SelectedModelAsset(
        assetPath: pairedAsset.assetPath,
        sizeBytes: pairedAsset.sizeBytes,
        usesSingleFileMode: false,
      );
    }

    return null;
  }

  Future<_AssetInfo> _assetInfo(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return _AssetInfo(
        assetPath: assetPath,
        exists: data.lengthInBytes > 0,
        sizeBytes: data.lengthInBytes,
      );
    } catch (_) {
      return _AssetInfo(assetPath: assetPath, exists: false, sizeBytes: 0);
    }
  }

  Future<OrtSession> _loadSession({_SelectedModelAsset? selectedModel}) async {
    if (_session != null &&
        selectedModel?.assetPath == _selectedModel?.assetPath) {
      return _session!;
    }

    final model = selectedModel ?? await _prepareModelAsset();

    if (kDebugMode) {
      debugPrint(
        'SILVAMANG AI offline selected model asset: ${model.assetPath}',
      );
      debugPrint(
        'SILVAMANG AI offline selected model size: ${model.sizeBytes}',
      );
      debugPrint(
        'SILVAMANG AI offline model mode: '
        '${model.usesSingleFileMode ? 'single-file' : 'external-data'}',
      );
    }

    try {
      _session = await OnnxRuntime().createSessionFromAsset(model.assetPath);
      _selectedModel = model;
      return _session!;
    } catch (error) {
      throw OfflinePredictionException(
        _failureReason(error, 'session_creation_failed'),
        'selected_model_asset=${model.assetPath} '
        'selected_model_file_size=${model.sizeBytes}',
      );
    }
  }

  Future<List<double>> _preprocessImage({required String imagePath}) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = image_lib.decodeImage(bytes);
    if (decoded == null) {
      throw const OfflinePredictionException('input_tensor_failed');
    }

    final oriented = image_lib.bakeOrientation(decoded);
    final resized = _resizeImageShortSide(oriented);
    final cropX = ((resized.width - _inputSize) / 2)
        .round()
        .clamp(0, max(0, resized.width - _inputSize))
        .toInt();
    final cropY = ((resized.height - _inputSize) / 2)
        .round()
        .clamp(0, max(0, resized.height - _inputSize))
        .toInt();
    final cropped = image_lib.copyCrop(
      resized,
      x: cropX,
      y: cropY,
      width: _inputSize,
      height: _inputSize,
    );
    final tensor = List<double>.filled(_inputElementCount, 0);
    var redOffset = 0;
    var greenOffset = _inputSize * _inputSize;
    var blueOffset = greenOffset * 2;

    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = cropped.getPixel(x, y);
        tensor[redOffset++] = ((pixel.r / 255.0) - _mean[0]) / _std[0];
        tensor[greenOffset++] = ((pixel.g / 255.0) - _mean[1]) / _std[1];
        tensor[blueOffset++] = ((pixel.b / 255.0) - _mean[2]) / _std[2];
      }
    }

    return tensor;
  }

  image_lib.Image _resizeImageShortSide(image_lib.Image source) {
    if (source.width <= source.height) {
      final height = (source.height * _resizeSize / source.width).round();
      return image_lib.copyResize(source, width: _resizeSize, height: height);
    }

    final width = (source.width * _resizeSize / source.height).round();
    return image_lib.copyResize(source, width: width, height: _resizeSize);
  }

  Future<Map<String, OrtValue>> _runSession(
    OrtSession session,
    String inputName,
    OrtValue inputTensor,
  ) async {
    final inputs = <String, OrtValue>{inputName: inputTensor};
    return session.run(inputs);
  }

  OrtValue? _selectOutput(Map<String, OrtValue> outputs, String? outputName) {
    if (outputName != null && outputs.containsKey(outputName)) {
      return outputs[outputName];
    }
    if (outputs.isNotEmpty) {
      return outputs.values.first;
    }
    return null;
  }

  Future<List<double>> _flattenOutput(OrtValue? value) async {
    if (value == null) {
      return <double>[];
    }

    final outputValue = await value.asFlattenedList();
    return _flattenToDoubleList(outputValue);
  }

  List<double> _flattenToDoubleList(Object? value) {
    if (value == null) {
      return <double>[];
    }

    if (value is num) {
      return <double>[value.toDouble()];
    }

    if (value is List) {
      final result = <double>[];
      for (final item in value) {
        result.addAll(_flattenToDoubleList(item));
      }
      return result;
    }

    return <double>[];
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(max);
    final exps = logits.map((logit) => exp(logit - maxLogit)).toList();
    final sumExp = exps.fold<double>(0, (sum, value) => sum + value);
    if (sumExp == 0) {
      return List<double>.filled(logits.length, 0);
    }
    return exps.map((value) => value / sumExp).toList();
  }

  List<Map<String, Object?>> _topK(
    List<double> probabilities,
    List<String> classOrder,
    int k,
  ) {
    final ranked = <({int index, double confidence})>[
      for (var i = 0; i < probabilities.length && i < classOrder.length; i++)
        (index: i, confidence: probabilities[i] * 100),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    return [
      for (var rank = 0; rank < min(k, ranked.length); rank++)
        {
          'rank': rank + 1,
          'species_id': null,
          'scientific_name': _displaySpeciesName(
            classOrder[ranked[rank].index],
          ),
          'common_name': null,
          'confidence': double.parse(
            ranked[rank].confidence.toStringAsFixed(2),
          ),
          'model_name': 'SILVAMANG EfficientNet-B0 Offline',
          'model_version': 'onnx-offline-0.2.0',
        },
    ];
  }

  String _displaySpeciesName(String value) {
    return value.replaceAll('_', ' ').trim();
  }

  String _failureReason(Object error, String fallback) {
    if (error is OfflinePredictionException) {
      return error.reason;
    }

    final text = error.toString().toLowerCase();
    for (final reason in const [
      'web_not_supported',
      'selected_image_missing',
      'class_order_missing',
      'model_asset_missing',
      'model_data_asset_missing',
      'session_creation_failed',
      'unsupported_model_format',
      'invalid_model_path',
      'input_tensor_failed',
      'inference_failed',
      'output_parse_failed',
    ]) {
      if (text.contains(reason)) {
        return reason;
      }
    }
    if (text.contains('unsupported') ||
        text.contains('opset') ||
        text.contains('ir version')) {
      return 'unsupported_model_format';
    }
    if (text.contains('no such file') ||
        text.contains('not found') ||
        text.contains('invalid path')) {
      return 'invalid_model_path';
    }
    return fallback;
  }

  OfflineModelDiagnosticResult _diagnosticResult({
    bool platformSupported = true,
    bool classOrderLoaded = true,
    int classCount = 0,
    bool singleModelAssetLoaded = false,
    bool pairedModelAssetLoaded = false,
    bool pairedDataAssetLoaded = false,
    String selectedModelAsset = '',
    int selectedModelFileSize = 0,
    bool sessionCreationAttempted = false,
    bool sessionCreationSucceeded = false,
    bool dummyInferenceSucceeded = false,
    String? failureReason,
    String? technicalDetail,
    List<String> inputNames = const [],
    List<String> outputNames = const [],
  }) {
    final result = OfflineModelDiagnosticResult(
      platformSupported: platformSupported,
      classOrderLoaded: classOrderLoaded,
      classCount: classCount,
      singleModelAssetLoaded: singleModelAssetLoaded,
      pairedModelAssetLoaded: pairedModelAssetLoaded,
      pairedDataAssetLoaded: pairedDataAssetLoaded,
      selectedModelAsset: selectedModelAsset,
      selectedModelFileSize: selectedModelFileSize,
      sessionCreationAttempted: sessionCreationAttempted,
      sessionCreationSucceeded: sessionCreationSucceeded,
      dummyInferenceSucceeded: dummyInferenceSucceeded,
      failureReason: failureReason,
      technicalDetail: technicalDetail,
      inputNames: inputNames,
      outputNames: outputNames,
    );

    if (kDebugMode) {
      debugPrint(
        'SILVAMANG AI offline diagnostic: '
        'ready=${result.isReady}, '
        'classes=${result.classCount}, '
        'singleAsset=${result.singleModelAssetLoaded}, '
        'pairedModelAsset=${result.pairedModelAssetLoaded}, '
        'pairedDataAsset=${result.pairedDataAssetLoaded}, '
        'selectedAsset=${result.selectedModelAsset}, '
        'selectedSize=${result.selectedModelFileSize}, '
        'sessionAttempted=${result.sessionCreationAttempted}, '
        'session=${result.sessionCreationSucceeded}, '
        'dummyInference=${result.dummyInferenceSucceeded}, '
        'inputNames=${result.inputNames}, '
        'outputNames=${result.outputNames}, '
        'reason=${result.failureReason ?? 'none'}, '
        'detail=${result.technicalDetail ?? 'none'}',
      );
    }

    return result;
  }

  String _sanitizeError(Object error) {
    final text = error.toString().replaceAll('\n', ' ').trim();
    if (text.length <= 360) {
      return text;
    }
    return '${text.substring(0, 360)}...';
  }
}

class _AssetInfo {
  const _AssetInfo({
    required this.assetPath,
    required this.exists,
    required this.sizeBytes,
  });

  final String assetPath;
  final bool exists;
  final int sizeBytes;
}

class _SelectedModelAsset {
  const _SelectedModelAsset({
    required this.assetPath,
    required this.sizeBytes,
    required this.usesSingleFileMode,
  });

  final String assetPath;
  final int sizeBytes;
  final bool usesSingleFileMode;
}
