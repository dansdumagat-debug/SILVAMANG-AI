import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/identification/data/services/offline_prediction_service.dart';

void main() {
  group('offline model output and class-order compatibility', () {
    test('accepts equal ONNX output and class-order counts', () {
      expect(
        () => OfflinePredictionService.validateOutputClassCount(
          outputCount: 30,
          classCount: 30,
        ),
        returnsNormally,
      );
    });

    test('rejects an ONNX model with fewer outputs than class labels', () {
      expect(
        () => OfflinePredictionService.validateOutputClassCount(
          outputCount: 10,
          classCount: 30,
        ),
        throwsA(
          isA<OfflinePredictionException>()
              .having(
                (error) => error.reason,
                'reason',
                OfflinePredictionService.outputClassCountMismatchReason,
              )
              .having(
                (error) => error.detail,
                'detail',
                allOf(contains('(10)'), contains('(30)')),
              ),
        ),
      );
    });

    test('rejects an ONNX model with more outputs than class labels', () {
      expect(
        () => OfflinePredictionService.validateOutputClassCount(
          outputCount: 30,
          classCount: 10,
        ),
        throwsA(
          isA<OfflinePredictionException>().having(
            (error) => error.reason,
            'reason',
            OfflinePredictionService.outputClassCountMismatchReason,
          ),
        ),
      );
    });

    test('diagnostic readiness requires an exact output count match', () {
      final mismatch = _diagnostic(classCount: 30, outputCount: 10);
      final compatible = _diagnostic(classCount: 30, outputCount: 30);

      expect(mismatch.isReady, isFalse);
      expect(compatible.isReady, isTrue);
    });
  });
}

OfflineModelDiagnosticResult _diagnostic({
  required int classCount,
  required int outputCount,
}) {
  return OfflineModelDiagnosticResult(
    platformSupported: true,
    classOrderLoaded: true,
    classCount: classCount,
    singleModelAssetLoaded: true,
    pairedModelAssetLoaded: false,
    pairedDataAssetLoaded: false,
    selectedModelAsset: 'assets/models/test.onnx',
    selectedModelFileSize: 1,
    sessionCreationAttempted: true,
    sessionCreationSucceeded: true,
    dummyInferenceSucceeded: true,
    outputCount: outputCount,
  );
}
