import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/identification/data/services/offline_prediction_service.dart';

void main() {
  test(
    'mobile bundle uses the uploaded classifier label order and version',
    () {
      final labels = jsonDecode(
        File('assets/models/class_order.json').readAsStringSync(),
      );
      final serverLabels = jsonDecode(
        File(
          '../silvamang_ai_service/models/EfficientNet-B0/class_order.json',
        ).readAsStringSync(),
      );
      final metadata = jsonDecode(
        File('assets/models/model_metadata.json').readAsStringSync(),
      );
      expect(labels, serverLabels);
      expect(labels, hasLength(29));
      expect(labels.last, 'unknown');
      expect(metadata['class_count'], labels.length);
      expect(metadata['version'], OfflinePredictionService.modelVersion);
      expect(metadata['source_provenance']['checkpoint_selection'], 'last');
      expect(
        File(
          'assets/models/efficientnet_b0_silvamang_single.onnx',
        ).lengthSync(),
        greaterThan(1000000),
      );
    },
  );
}
