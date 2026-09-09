import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/camera_measurement_result.dart';

class CameraMeasurementSelection {
  const CameraMeasurementSelection({this.heightResult, this.canopyWidthResult});

  final CameraMeasurementResult? heightResult;
  final CameraMeasurementResult? canopyWidthResult;

  CameraMeasurementResult? get latestResult {
    final height = heightResult;
    final canopy = canopyWidthResult;
    if (height == null) {
      return canopy;
    }
    if (canopy == null) {
      return height;
    }

    return height.createdAt.isAfter(canopy.createdAt) ? height : canopy;
  }

  bool get hasAny => heightResult != null || canopyWidthResult != null;

  CameraMeasurementSelection select(CameraMeasurementResult result) {
    if (result.measurementType == 'tree_height') {
      return CameraMeasurementSelection(
        heightResult: result,
        canopyWidthResult: canopyWidthResult,
      );
    }

    return CameraMeasurementSelection(
      heightResult: heightResult,
      canopyWidthResult: result,
    );
  }

  CameraMeasurementSelection clearType(String measurementType) {
    if (measurementType == 'tree_height') {
      return CameraMeasurementSelection(canopyWidthResult: canopyWidthResult);
    }

    if (measurementType == 'canopy_width') {
      return CameraMeasurementSelection(heightResult: heightResult);
    }

    return this;
  }
}

final cameraMeasurementSelectionProvider =
    StateProvider<CameraMeasurementSelection>(
      (ref) => const CameraMeasurementSelection(),
    );

final cameraMeasurementResultProvider = StateProvider<CameraMeasurementResult?>(
  (ref) => null,
);

void useCameraMeasurementResult(WidgetRef ref, CameraMeasurementResult result) {
  final selection = ref.read(cameraMeasurementSelectionProvider).select(result);
  ref.read(cameraMeasurementSelectionProvider.notifier).state = selection;
  ref.read(cameraMeasurementResultProvider.notifier).state =
      selection.latestResult;
}

void clearCameraMeasurementSelection(WidgetRef ref) {
  ref.read(cameraMeasurementSelectionProvider.notifier).state =
      const CameraMeasurementSelection();
  ref.read(cameraMeasurementResultProvider.notifier).state = null;
}

void clearCameraMeasurementSelectionType(
  WidgetRef ref,
  String measurementType,
) {
  final selection = ref
      .read(cameraMeasurementSelectionProvider)
      .clearType(measurementType);
  ref.read(cameraMeasurementSelectionProvider.notifier).state = selection;
  ref.read(cameraMeasurementResultProvider.notifier).state =
      selection.latestResult;
}
