import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../measurement/presentation/controllers/field_distance_controller.dart';
import '../../data/models/camera_measurement_result.dart';
import '../../data/services/measurement_geometry.dart';
import '../controllers/camera_measurement_controller.dart';

enum _CameraMeasurementType { treeHeight, canopyWidth }

enum _CameraCaptureMode { normal, extendedSweep }

class CameraPointingMeasurementPage extends ConsumerStatefulWidget {
  const CameraPointingMeasurementPage({super.key, this.initialType});

  final String? initialType;

  @override
  ConsumerState<CameraPointingMeasurementPage> createState() =>
      _CameraPointingMeasurementPageState();
}

class _CameraPointingMeasurementPageState
    extends ConsumerState<CameraPointingMeasurementPage> {
  static const double _prototypeVerticalFovDegrees = 60;
  static const double _prototypeHorizontalFovDegrees = 70;
  static const double _minimumLiveSpanFraction = 0.015;
  static const double _maxLiveAngleRadians = 1.3962634015954636; // 80 degrees.
  static const double _maxExtendedAngleRadians =
      2.792526803190927; // 160 degrees.
  static const int _orientationSampleCount = 7;
  static const int _minimumStableOrientationSamples = 5;
  static const double _maximumStableSpreadDegrees = 2.5;
  static const double _minimumGravityMagnitude = 8;
  static const double _maximumGravityMagnitude = 12;

  final _manualDistanceController = TextEditingController();
  final _cameraHeightController = TextEditingController(text: '1.5');

  CameraController? _cameraController;
  _CameraMeasurementType _type = _CameraMeasurementType.treeHeight;
  _CameraCaptureMode _captureMode = _CameraCaptureMode.normal;
  CameraMeasurementPoint? _basePoint;
  CameraMeasurementPoint? _topPoint;
  CameraMeasurementPoint? _leftEdgePoint;
  CameraMeasurementPoint? _rightEdgePoint;
  CameraMeasurementResult? _result;
  String? _errorMessage;
  String? _cameraStatus;
  Offset? _liveStart;
  Offset? _liveEnd;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastGyroscopeTimestamp;
  DateTime? _lastOrientationUiUpdate;
  double _trackedVerticalRadians = 0;
  double _trackedHorizontalRadians = 0;
  final List<double> _elevationSamples = [];
  double? _currentElevationRadians;
  double? _baseElevationRadians;
  double? _orientationSpreadDegrees;
  bool _orientationStable = false;
  String _orientationSensorStatus = 'Waiting for phone orientation sensor.';
  bool _isCameraLoading = true;
  final bool _isSettingPoint = false;
  bool _isLiveDragging = false;
  bool _isSensorTracking = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType == 'canopy_width'
        ? _CameraMeasurementType.canopyWidth
        : _CameraMeasurementType.treeHeight;
    _manualDistanceController.addListener(_refreshLiveEstimate);
    _cameraHeightController.addListener(_refreshLiveEstimate);
    _startOrientationTracking();
    _initializeCamera();
  }

  @override
  void dispose() {
    _manualDistanceController.removeListener(_refreshLiveEstimate);
    _cameraHeightController.removeListener(_refreshLiveEstimate);
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _manualDistanceController.dispose();
    _cameraHeightController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isCameraLoading = true;
      _cameraStatus = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isCameraLoading = false;
          _cameraStatus =
              'Camera unavailable. Live camera measurement cannot start.';
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraLoading = false;
        _cameraStatus = 'Camera ready.';
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCameraLoading = false;
        _cameraStatus =
            error.description ??
            'Camera unavailable. Live camera measurement cannot start.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCameraLoading = false;
        _cameraStatus =
            'Camera unavailable. Live camera measurement cannot start.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldDistance = ref
        .watch(fieldDistanceControllerProvider)
        .measurement;
    final distanceM = _selectedDistanceM(fieldDistance.distanceMeters);
    final distanceSource = _selectedDistanceSource(
      fieldDistance.distanceMeters,
    );
    final cameraReady = _cameraController?.value.isInitialized == true;
    final currentResult = _result;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        backgroundColor: AppColors.mintBackground,
        foregroundColor: AppColors.textDark,
        surfaceTintColor: AppColors.mintBackground,
        leading: const SilvamangBackButton(
          fallbackRouteName: RouteNames.measurement,
        ),
        title: Text('Camera Measurement', style: AppTextStyles.titleMedium),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: SilvamangBadge(
                label: _typeLabel,
                type: SilvamangBadgeType.info,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          _MeasurementHeroHeader(
            type: _type,
            hasDistance: distanceM != null && distanceM > 0,
          ),
          const SizedBox(height: AppSpacing.md),
          _TypeSelector(type: _type, onSelected: _selectType),
          if (_type == _CameraMeasurementType.treeHeight) ...[
            const SizedBox(height: AppSpacing.md),
            _CaptureModeSelector(
              mode: _captureMode,
              onSelected: _selectCaptureMode,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraLoading)
                    const _CameraPlaceholder(text: 'Starting camera...')
                  else if (cameraReady)
                    CameraPreview(_cameraController!)
                  else
                    const _CameraPlaceholder(
                      text:
                          'Camera unavailable. Live camera measurement cannot start.',
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.16),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.34),
                        ],
                      ),
                    ),
                  ),
                  _MeasurementGuideOverlay(type: _type),
                  _PointMarkerOverlay(
                    type: _type,
                    basePoint: _basePoint,
                    topPoint: _topPoint,
                    leftEdgePoint: _leftEdgePoint,
                    rightEdgePoint: _rightEdgePoint,
                  ),
                  _LiveMeasurementOverlay(
                    type: _type,
                    mode: _captureMode,
                    start: _liveStart,
                    end: _liveEnd,
                    result: currentResult,
                    hasDistanceReference: distanceM != null && distanceM > 0,
                    isDragging: _isLiveDragging,
                  ),
                  const _CrosshairOverlay(),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    top: AppSpacing.md,
                    child: _LiveTopOverlay(
                      stepLabel: _stepLabel,
                      instruction: _stepInstruction,
                      type: _type,
                      result: currentResult,
                      hasDistanceReference: distanceM != null && distanceM > 0,
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.sm,
                    top: 106,
                    child: _CameraModeRail(
                      type: _type,
                      onSelected: _selectType,
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: _CameraLiveControls(
                      actionText: _actionButtonText,
                      actionIcon:
                          _captureMode == _CameraCaptureMode.extendedSweep
                          ? Icons.unfold_more_rounded
                          : null,
                      isTracking: _isSensorTracking,
                      canStart:
                          cameraReady &&
                          !_isSettingPoint &&
                          (!_isExtendedMode || _orientationStable),
                      canUseResult:
                          currentResult != null &&
                          currentResult.qualityAccepted &&
                          !_isSensorTracking,
                      onToggle: () =>
                          _toggleLivePointing(distanceM, distanceSource),
                      onReset: _reset,
                      onUseResult:
                          currentResult == null ||
                              !currentResult.qualityAccepted ||
                              _isSensorTracking
                          ? null
                          : () => _useCurrentResult(currentResult),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LiveStatusStrip(
            text: _liveStatusText,
            isTracking: _isSensorTracking,
            hasDistance: distanceM != null && distanceM > 0,
          ),
          const SizedBox(height: AppSpacing.md),
          _DistanceGuidanceBanner(
            type: _type,
            mode: _captureMode,
            distanceM: distanceM,
            result: currentResult,
            isTracking: _isSensorTracking,
            orientationStable: _orientationStable,
            stabilityProgress: _orientationHoldProgress,
            currentElevationDegrees: _currentElevationRadians == null
                ? null
                : MeasurementGeometry.radiansToDegrees(
                    _currentElevationRadians!,
                  ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.warningOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _DistanceInputCard(
            type: _type,
            fieldDistanceAvailable: fieldDistance.hasDistance,
            fieldDistanceM: fieldDistance.distanceMeters,
            manualDistanceController: _manualDistanceController,
            cameraHeightController: _cameraHeightController,
            onMeasureDistance: () =>
                context.pushNamed(RouteNames.fieldDistance),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (currentResult != null)
            _CameraResultCard(
              result: currentResult,
              onUseResult: currentResult.qualityAccepted
                  ? () => _useCurrentResult(currentResult)
                  : null,
            )
          else
            _LiveMeasurementInstructionCard(type: _type, mode: _captureMode),
          const SizedBox(height: AppSpacing.lg),
          _StatusCard(
            engineStatus: _captureMode == _CameraCaptureMode.extendedSweep
                ? _orientationSpreadDegrees == null
                      ? _orientationSensorStatus
                      : '$_orientationSensorStatus Stability spread: ${_orientationSpreadDegrees!.toStringAsFixed(1)} degrees.'
                : 'Phone motion analysis starts with the live control.',
            distanceM: distanceM,
            distanceSource: distanceSource,
            cameraStatus: _cameraStatus,
            livePointingStatus: _livePointingStatus,
          ),
          const SizedBox(height: AppSpacing.lg),
          _PointSummary(
            type: _type,
            basePoint: _basePoint,
            topPoint: _topPoint,
            leftEdgePoint: _leftEdgePoint,
            rightEdgePoint: _rightEdgePoint,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _PrototypeWarningCard(),
        ],
      ),
    );
  }

  String get _typeLabel {
    return _type == _CameraMeasurementType.treeHeight
        ? 'Tree Height'
        : 'Canopy Width';
  }

  bool get _isExtendedMode {
    return _type == _CameraMeasurementType.treeHeight &&
        _captureMode == _CameraCaptureMode.extendedSweep;
  }

  double get _orientationHoldProgress {
    if (_orientationStable) {
      return 1;
    }
    if (_elevationSamples.isEmpty) {
      return 0;
    }

    final sampleProgress =
        (_elevationSamples.length / _minimumStableOrientationSamples)
            .clamp(0.0, 1.0)
            .toDouble();
    final spread = _orientationSpreadDegrees;
    if (spread == null || spread <= 0) {
      return sampleProgress;
    }

    final steadinessProgress = (_maximumStableSpreadDegrees / spread)
        .clamp(0.0, 1.0)
        .toDouble();
    return min(sampleProgress, steadinessProgress);
  }

  String get _stepLabel {
    if (_isExtendedMode) {
      if (_isSensorTracking) {
        return _orientationStable && _hasLiveMeasurement
            ? 'Ready to lock'
            : 'Extended sweep active';
      }
      return _result == null ? 'Start at tree base' : 'Measurement ready';
    }

    if (_type == _CameraMeasurementType.treeHeight) {
      return _basePoint == null
          ? 'Step 1 of 2'
          : _topPoint == null
          ? 'Step 2 of 2'
          : _isSensorTracking
          ? 'Measuring live'
          : 'Measurement ready';
    }
    return _leftEdgePoint == null
        ? 'Step 1 of 2'
        : _rightEdgePoint == null
        ? 'Step 2 of 2'
        : _isSensorTracking
        ? 'Measuring live'
        : 'Measurement ready';
  }

  String get _stepInstruction {
    if (_isExtendedMode) {
      if (_isSensorTracking) {
        return _orientationStable && _hasLiveMeasurement
            ? 'Top is ready. Tap Lock Height.'
            : 'Move from the base to the top, then use Quick Hold.';
      }
      if (_result != null) {
        return 'Extended height captured. Check the position result below.';
      }
      return _orientationStable
          ? 'Aim at the trunk base, then start the extended sweep.'
          : 'Aim at the trunk base until Quick Hold is ready.';
    }

    if (_type == _CameraMeasurementType.treeHeight) {
      return _basePoint == null
          ? 'Point at the tree base, tap Start Live Height, then move the phone upward.'
          : _topPoint == null
          ? 'Move the camera upward to the top. The estimate updates live.'
          : 'Live height captured. Start again if you need another pass.';
    }
    return _leftEdgePoint == null
        ? 'Point at one canopy edge, tap Start Live Width, then pan the phone sideways.'
        : _rightEdgePoint == null
        ? 'Pan the camera across to the other edge. The estimate updates live.'
        : 'Live width captured. Start again if you need another pass.';
  }

  String get _actionButtonText {
    if (_isExtendedMode) {
      return _isSensorTracking ? 'Lock Height' : 'Start Sweep';
    }

    if (_isSensorTracking) {
      return _type == _CameraMeasurementType.treeHeight
          ? 'Lock Live Height'
          : 'Lock Live Width';
    }
    return _type == _CameraMeasurementType.treeHeight
        ? 'Start Live Height'
        : 'Start Live Width';
  }

  String get _liveStatusText {
    if (_isExtendedMode) {
      if (_isSensorTracking) {
        if (_result != null && !_result!.qualityAccepted) {
          final recommended = _result!.recommendedDistanceM;
          return recommended != null && recommended.isFinite
              ? 'Too close during the sweep. Move back to at least ${recommended.toStringAsFixed(1)} m and restart.'
              : 'Too close during the sweep. Move farther back and restart.';
        }
        return _orientationStable && _hasLiveMeasurement
            ? 'Top is ready. Tap Lock Height.'
            : 'Sweep upward, then hold briefly at the top.';
      }
      if (_result != null && !_result!.qualityAccepted) {
        final recommended = _result!.recommendedDistanceM;
        return recommended != null && recommended.isFinite
            ? 'Too close for a stable result. Move back to at least ${recommended.toStringAsFixed(1)} m.'
            : 'Too close for a stable result. Move farther back and measure again.';
      }
      if (_result != null) {
        return 'Extended height estimate is ready. Use Result to attach it to the scan.';
      }
      if (_hasLiveMeasurement) {
        return 'Extended sweep captured. Add distance to calculate meters.';
      }
      return _orientationStable
          ? 'Phone is steady. Start the extended sweep at the tree base.'
          : 'Aim at the tree base and hold briefly.';
    }

    if (_hasLiveMeasurement && _result != null) {
      if (!_result!.qualityAccepted) {
        final recommended = _result!.recommendedDistanceM;
        return recommended != null && recommended.isFinite
            ? 'Too close. Move back to at least ${recommended.toStringAsFixed(1)} m and measure again.'
            : 'Too close. Move farther back and measure again.';
      }
      final label = _type == _CameraMeasurementType.treeHeight
          ? 'height'
          : 'canopy width';
      return 'Live $label estimate is ready. Use Result to attach it to the scan.';
    }
    if (_hasLiveMeasurement) {
      return 'Phone movement captured. Add field distance or manual distance for meters.';
    }
    if (_type == _CameraMeasurementType.treeHeight) {
      return 'Point at the base, start live height, then move the phone upward.';
    }
    return 'Point at one canopy edge, start live width, then pan the phone sideways.';
  }

  String get _livePointingStatus {
    if (_isExtendedMode) {
      if (_isSensorTracking) {
        return _orientationStable && _hasLiveMeasurement
            ? 'Top endpoint is steady and ready to lock.'
            : 'Tracking the continuous base-to-top sweep.';
      }
      if (_result != null) {
        return _result!.qualityAccepted
            ? 'Extended base-to-top sweep captured.'
            : 'Captured, but the viewing angle is too steep.';
      }
      return _orientationStable
          ? 'Ready to start at the base.'
          : _orientationSensorStatus;
    }

    if (_isSensorTracking) {
      return _type == _CameraMeasurementType.treeHeight
          ? 'Tracking phone movement upward.'
          : 'Tracking phone movement sideways.';
    }
    if (_hasLiveMeasurement) {
      return 'Phone movement captured.';
    }
    return 'Ready. Tap start, then move the phone.';
  }

  bool get _hasLiveMeasurement {
    final line = _orderedLiveLine;
    if (line == null) {
      return false;
    }
    return _liveSpanFraction(line) >= _minimumLiveSpanFraction;
  }

  void _startOrientationTracking() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen(
          _handleAccelerometerEvent,
          onError: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _orientationStable = false;
              _currentElevationRadians = null;
              _orientationSpreadDegrees = null;
              _orientationSensorStatus =
                  'Phone orientation sensor is unavailable on this device.';
            });
          },
          cancelOnError: true,
        );
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    if (!mounted) {
      return;
    }

    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final elevation = MeasurementGeometry.cameraElevationRadians(
      x: event.x,
      y: event.y,
      z: event.z,
    );

    if (elevation == null ||
        magnitude < _minimumGravityMagnitude ||
        magnitude > _maximumGravityMagnitude) {
      _elevationSamples.clear();
      _publishOrientationState(
        elevation: elevation,
        spreadDegrees: null,
        isStable: false,
        status: 'Phone is moving. Hold it steady before capturing.',
      );
      return;
    }

    _elevationSamples.add(elevation);
    if (_elevationSamples.length > _orientationSampleCount) {
      _elevationSamples.removeAt(0);
    }

    final average =
        _elevationSamples.reduce((a, b) => a + b) / _elevationSamples.length;
    final lowest = _elevationSamples.reduce((a, b) => a < b ? a : b);
    final highest = _elevationSamples.reduce((a, b) => a > b ? a : b);
    final spreadDegrees = MeasurementGeometry.radiansToDegrees(
      highest - lowest,
    );
    final hasEnoughSamples =
        _elevationSamples.length >= _minimumStableOrientationSamples;
    final isStable =
        hasEnoughSamples && spreadDegrees <= _maximumStableSpreadDegrees;
    final status = !hasEnoughSamples
        ? 'Quick Hold is checking the phone...'
        : isStable
        ? 'Phone is steady and ready to capture.'
        : 'Pause briefly until Quick Hold is ready.';

    _publishOrientationState(
      elevation: average,
      spreadDegrees: spreadDegrees,
      isStable: isStable,
      status: status,
    );
  }

  void _publishOrientationState({
    required double? elevation,
    required double? spreadDegrees,
    required bool isStable,
    required String status,
  }) {
    final now = DateTime.now();
    final shouldUpdate =
        _lastOrientationUiUpdate == null ||
        now.difference(_lastOrientationUiUpdate!) >=
            const Duration(milliseconds: 100) ||
        isStable != _orientationStable;
    if (!shouldUpdate) {
      return;
    }

    final becameStable = isStable && !_orientationStable;
    _lastOrientationUiUpdate = now;
    setState(() {
      _currentElevationRadians = elevation;
      _orientationSpreadDegrees = spreadDegrees;
      _orientationStable = isStable;
      _orientationSensorStatus = status;
    });
    if (becameStable && _isExtendedMode) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _selectType(_CameraMeasurementType type) {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    setState(() {
      _type = type;
      if (type == _CameraMeasurementType.canopyWidth) {
        _captureMode = _CameraCaptureMode.normal;
      }
      _basePoint = null;
      _topPoint = null;
      _leftEdgePoint = null;
      _rightEdgePoint = null;
      _liveStart = null;
      _liveEnd = null;
      _isLiveDragging = false;
      _isSensorTracking = false;
      _trackedVerticalRadians = 0;
      _trackedHorizontalRadians = 0;
      _lastGyroscopeTimestamp = null;
      _baseElevationRadians = null;
      _result = null;
      _errorMessage = null;
    });
  }

  void _selectCaptureMode(_CameraCaptureMode mode) {
    if (_captureMode == mode) {
      return;
    }

    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    setState(() {
      _captureMode = mode;
      _basePoint = null;
      _topPoint = null;
      _leftEdgePoint = null;
      _rightEdgePoint = null;
      _liveStart = null;
      _liveEnd = null;
      _isLiveDragging = false;
      _isSensorTracking = false;
      _trackedVerticalRadians = 0;
      _trackedHorizontalRadians = 0;
      _lastGyroscopeTimestamp = null;
      _baseElevationRadians = null;
      _result = null;
      _errorMessage = null;
    });
  }

  void _refreshLiveEstimate() {
    if (!mounted) {
      return;
    }

    if (!_hasLiveMeasurement) {
      setState(() => _errorMessage = null);
      return;
    }

    final fieldDistance = ref.read(fieldDistanceControllerProvider).measurement;
    _applyLiveEstimate(
      _selectedDistanceM(fieldDistance.distanceMeters),
      _selectedDistanceSource(fieldDistance.distanceMeters),
    );
  }

  void _toggleLivePointing(double? distanceM, String distanceSource) {
    if (_isSensorTracking) {
      _lockLivePointing(distanceM, distanceSource);
      return;
    }
    _startLivePointing(distanceM, distanceSource);
  }

  void _startLivePointing(double? distanceM, String distanceSource) {
    final baseElevation = _currentElevationRadians;
    if (_isExtendedMode && (!_orientationStable || baseElevation == null)) {
      setState(() {
        _errorMessage =
            'Aim at the tree base and wait for the short Quick Hold.';
      });
      return;
    }

    _gyroscopeSubscription?.cancel();
    final initialLine = _lineFromSensorAngle(0);
    final timestamp = DateTime.now();

    setState(() {
      _trackedVerticalRadians = 0;
      _trackedHorizontalRadians = 0;
      _lastGyroscopeTimestamp = null;
      _baseElevationRadians = _isExtendedMode ? baseElevation : null;
      _liveStart = initialLine.first;
      _liveEnd = initialLine.second;
      _isSensorTracking = true;
      _isLiveDragging = true;
      _result = null;
      _errorMessage = null;
      if (_isExtendedMode) {
        final angleDegrees = MeasurementGeometry.radiansToDegrees(
          baseElevation!,
        );
        _basePoint = _pointFromNormalized(
          'base',
          initialLine.first,
          timestamp,
          locationStatus:
              'Extended sweep base angle: ${angleDegrees.toStringAsFixed(1)} degrees',
        );
        _topPoint = null;
        _leftEdgePoint = null;
        _rightEdgePoint = null;
      } else {
        _syncCapturedPointsFromLiveLine(timestamp);
      }
    });

    _gyroscopeSubscription =
        gyroscopeEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
          _handleGyroscopeEvent,
          onError: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isSensorTracking = false;
              _isLiveDragging = false;
              _errorMessage =
                  'Phone motion sensor is unavailable on this device. Live camera measurement cannot run.';
            });
          },
          cancelOnError: true,
        );

    _applyLiveEstimate(distanceM, distanceSource);
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    if (!_isSensorTracking || !mounted) {
      return;
    }

    final previous = _lastGyroscopeTimestamp;
    final now = event.timestamp;
    _lastGyroscopeTimestamp = now;
    if (previous == null) {
      return;
    }

    final deltaSeconds = now.difference(previous).inMicroseconds / 1000000;
    if (deltaSeconds <= 0 || deltaSeconds > 0.25) {
      return;
    }

    final verticalLimit = _isExtendedMode
        ? _maxExtendedAngleRadians
        : _maxLiveAngleRadians;
    _trackedVerticalRadians = (_trackedVerticalRadians + event.x * deltaSeconds)
        .clamp(-verticalLimit, verticalLimit)
        .toDouble();
    _trackedHorizontalRadians =
        (_trackedHorizontalRadians + event.y * deltaSeconds)
            .clamp(-_maxLiveAngleRadians, _maxLiveAngleRadians)
            .toDouble();

    final fieldDistance = ref.read(fieldDistanceControllerProvider).measurement;
    _updateSensorLiveLine(
      _selectedDistanceM(fieldDistance.distanceMeters),
      _selectedDistanceSource(fieldDistance.distanceMeters),
    );
  }

  void _updateSensorLiveLine(double? distanceM, String distanceSource) {
    final angle = _activeSensorAngleRadians.abs();
    final line = _lineFromSensorAngle(angle);

    setState(() {
      _liveStart = line.first;
      _liveEnd = line.second;
      _errorMessage = null;
      _syncCapturedPointsFromLiveLine(DateTime.now());
    });
    _applyLiveEstimate(distanceM, distanceSource);
  }

  void _lockLivePointing(double? distanceM, String distanceSource) {
    if (_isExtendedMode) {
      final baseElevation = _baseElevationRadians;
      final topElevation = _currentElevationRadians;
      if (!_orientationStable ||
          baseElevation == null ||
          topElevation == null) {
        setState(() {
          _errorMessage =
              'Keep the crosshair at the tree top until Quick Hold is ready.';
        });
        return;
      }

      final correctedAngle = MeasurementGeometry.angularDifferenceRadians(
        baseElevation,
        topElevation,
      );
      if (correctedAngle < MeasurementGeometry.degreesToRadians(1)) {
        setState(() {
          _errorMessage =
              'The sweep is too short. Continue moving toward the tree top.';
        });
        return;
      }

      _trackedVerticalRadians = correctedAngle
          .clamp(0.0, _maxExtendedAngleRadians)
          .toDouble();
      final correctedLine = _lineFromSensorAngle(correctedAngle);
      _liveStart = correctedLine.first;
      _liveEnd = correctedLine.second;
      _syncCapturedPointsFromLiveLine(DateTime.now());
      final topAngleDegrees = MeasurementGeometry.radiansToDegrees(
        topElevation,
      );
      _topPoint = _pointFromNormalized(
        'top',
        correctedLine.second,
        DateTime.now(),
        locationStatus:
            'Extended sweep top angle: ${topAngleDegrees.toStringAsFixed(1)} degrees',
      );
    }

    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;

    final result = _buildLiveMeasurementResult(distanceM, distanceSource);
    setState(() {
      _isSensorTracking = false;
      _isLiveDragging = false;
      if (result != null) {
        _result = result;
        _errorMessage = null;
      } else if (distanceM == null || distanceM <= 0) {
        _errorMessage =
            'Distance is required for metric estimate. Use Field Distance Meter or enter manual distance.';
      } else if (_isExtendedMode) {
        _errorMessage =
            'The viewing angle is too steep to calculate safely. Move farther back and restart the sweep.';
      } else {
        _errorMessage =
            'Move the phone farther from the start point before locking the measurement.';
      }
    });
  }

  double get _activeSensorAngleRadians {
    return _type == _CameraMeasurementType.treeHeight
        ? _trackedVerticalRadians
        : _trackedHorizontalRadians;
  }

  _LiveLine _lineFromSensorAngle(double angleRadians) {
    final fovDegrees = _type == _CameraMeasurementType.treeHeight
        ? _prototypeVerticalFovDegrees
        : _prototypeHorizontalFovDegrees;
    final span = (_radiansToDegrees(angleRadians.abs()) / fovDegrees)
        .clamp(0.0, 0.72)
        .toDouble();

    if (_type == _CameraMeasurementType.treeHeight) {
      const base = Offset(0.5, 0.78);
      return _LiveLine(
        first: base,
        second: Offset(base.dx, max(0.08, base.dy - span)),
      );
    }

    const centerY = 0.5;
    final halfSpan = span / 2;
    return _LiveLine(
      first: Offset(max(0.04, 0.5 - halfSpan), centerY),
      second: Offset(min(0.96, 0.5 + halfSpan), centerY),
    );
  }

  _LiveLine? get _orderedLiveLine {
    final start = _liveStart;
    final end = _liveEnd;
    if (start == null || end == null) {
      return null;
    }

    if (_type == _CameraMeasurementType.treeHeight) {
      return start.dy >= end.dy
          ? _LiveLine(first: start, second: end)
          : _LiveLine(first: end, second: start);
    }

    return start.dx <= end.dx
        ? _LiveLine(first: start, second: end)
        : _LiveLine(first: end, second: start);
  }

  void _syncCapturedPointsFromLiveLine(DateTime timestamp) {
    final line = _orderedLiveLine;
    if (line == null) {
      return;
    }

    if (_type == _CameraMeasurementType.treeHeight) {
      _basePoint = _isExtendedMode
          ? _basePoint ?? _pointFromNormalized('base', line.first, timestamp)
          : _pointFromNormalized('base', line.first, timestamp);
      _topPoint = _pointFromNormalized('top', line.second, timestamp);
      _leftEdgePoint = null;
      _rightEdgePoint = null;
    } else {
      _leftEdgePoint = _pointFromNormalized('left_edge', line.first, timestamp);
      _rightEdgePoint = _pointFromNormalized(
        'right_edge',
        line.second,
        timestamp,
      );
      _basePoint = null;
      _topPoint = null;
    }
  }

  CameraMeasurementPoint _pointFromNormalized(
    String label,
    Offset point,
    DateTime timestamp, {
    String locationStatus = 'Live camera point',
  }) {
    final orientation =
        _cameraController?.value.deviceOrientation.name ?? 'unknown';
    return CameraMeasurementPoint(
      label: label,
      timestamp: timestamp,
      frameCenterX: point.dx,
      frameCenterY: point.dy,
      deviceOrientation: orientation,
      locationStatus: locationStatus,
    );
  }

  void _applyLiveEstimate(double? distanceM, String distanceSource) {
    final result = _buildLiveMeasurementResult(distanceM, distanceSource);
    setState(() => _result = result);
  }

  CameraMeasurementResult? _buildLiveMeasurementResult(
    double? distanceM,
    String distanceSource,
  ) {
    final line = _orderedLiveLine;
    if (line == null || distanceM == null || distanceM <= 0) {
      return null;
    }

    final fovDegrees = _type == _CameraMeasurementType.treeHeight
        ? _prototypeVerticalFovDegrees
        : _prototypeHorizontalFovDegrees;
    final minimumAngleRadians =
        fovDegrees * _minimumLiveSpanFraction * pi / 180;
    final angleRadians = _activeSensorAngleRadians.abs();
    if (angleRadians < minimumAngleRadians) {
      return null;
    }

    final cameraHeightM = _selectedCameraHeightM();
    if (_type == _CameraMeasurementType.treeHeight && cameraHeightM == null) {
      return null;
    }

    final estimatedValue = _type == _CameraMeasurementType.treeHeight
        ? MeasurementGeometry.heightFromAngularSpan(
            distanceM: distanceM,
            cameraHeightM: cameraHeightM!,
            angleSpanRadians: angleRadians,
          )
        : MeasurementGeometry.widthFromAngularSpan(
            distanceM: distanceM,
            angleSpanRadians: angleRadians,
          );
    if (!estimatedValue.isFinite || estimatedValue <= 0) {
      return null;
    }

    final isExtendedHeight =
        _type == _CameraMeasurementType.treeHeight && _isExtendedMode;
    final guidance = _type == _CameraMeasurementType.treeHeight
        ? MeasurementGeometry.heightGuidance(
            distanceM: distanceM,
            cameraHeightM: cameraHeightM!,
            angleSpanRadians: angleRadians,
            estimatedHeightM: estimatedValue,
            maximumSpanDegrees: isExtendedHeight
                ? MeasurementGeometry.maximumExtendedHeightSpanDegrees
                : MeasurementGeometry.maximumHeightSpanDegrees,
          )
        : MeasurementGeometry.canopyGuidance(
            distanceM: distanceM,
            angleSpanRadians: angleRadians,
            estimatedWidthM: estimatedValue,
          );

    final timestamp = DateTime.now();
    final first = _pointFromNormalized(
      _type == _CameraMeasurementType.treeHeight ? 'base' : 'left_edge',
      line.first,
      timestamp,
    );
    final second = _pointFromNormalized(
      _type == _CameraMeasurementType.treeHeight ? 'top' : 'right_edge',
      line.second,
      timestamp,
    );

    return CameraMeasurementResult(
      measurementType: _type == _CameraMeasurementType.treeHeight
          ? 'tree_height'
          : 'canopy_width',
      measurementMode: isExtendedHeight
          ? 'extended_sweep'
          : 'live_camera_pointing',
      estimatedValueM: estimatedValue,
      methodUsed: isExtendedHeight
          ? 'extended_sensor_fusion_clinometer'
          : _type == _CameraMeasurementType.treeHeight
          ? 'clinometer_tangent_camera_height'
          : 'angular_span_width',
      distanceSource: distanceSource,
      distanceM: distanceM,
      basePoint: _type == _CameraMeasurementType.treeHeight
          ? isExtendedHeight
                ? _basePoint ?? first
                : first
          : null,
      topPoint: _type == _CameraMeasurementType.treeHeight
          ? isExtendedHeight
                ? _topPoint ?? second
                : second
          : null,
      leftEdgePoint: _type == _CameraMeasurementType.canopyWidth ? first : null,
      rightEdgePoint: _type == _CameraMeasurementType.canopyWidth
          ? second
          : null,
      arSupported: false,
      arUsed: false,
      reliability: guidance.isTooClose
          ? 'Too close'
          : _reliability(distanceSource),
      warningMessage: guidance.isTooClose
          ? _tooCloseWarning(guidance)
          : isExtendedHeight
          ? 'Extended sweep corrected with steady base and top orientation. Keep the same standing position throughout the sweep.'
          : 'Live phone-motion estimate. Accuracy depends on distance, camera height, and steady movement.',
      angularSpanDegrees: guidance.angleSpanDegrees,
      viewingAngleDegrees: guidance.viewingAngleDegrees,
      recommendedDistanceM: guidance.recommendedDistanceM,
      qualityAccepted: !guidance.isTooClose,
      createdAt: timestamp,
    );
  }

  String _tooCloseWarning(MeasurementPositionGuidance guidance) {
    final recommended = guidance.recommendedDistanceM;
    final distanceText = recommended != null && recommended.isFinite
        ? ' Move back to at least ${recommended.toStringAsFixed(1)} m.'
        : ' Move farther away.';
    return 'Too close: the viewing angle is too steep for a stable measurement.$distanceText Measure again before using this result.';
  }

  double _liveSpanFraction(_LiveLine line) {
    return _type == _CameraMeasurementType.treeHeight
        ? (line.first.dy - line.second.dy).abs()
        : (line.second.dx - line.first.dx).abs();
  }

  void _reset() {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    setState(() {
      _basePoint = null;
      _topPoint = null;
      _leftEdgePoint = null;
      _rightEdgePoint = null;
      _liveStart = null;
      _liveEnd = null;
      _isLiveDragging = false;
      _isSensorTracking = false;
      _trackedVerticalRadians = 0;
      _trackedHorizontalRadians = 0;
      _lastGyroscopeTimestamp = null;
      _baseElevationRadians = null;
      _result = null;
      _errorMessage = null;
    });
  }

  void _useCurrentResult(CameraMeasurementResult result) {
    if (!result.qualityAccepted) {
      setState(() {
        _errorMessage = _tooCloseWarning(
          MeasurementPositionGuidance(
            isTooClose: true,
            angleSpanDegrees: result.angularSpanDegrees ?? 0,
            viewingAngleDegrees: result.viewingAngleDegrees,
            recommendedDistanceM: result.recommendedDistanceM,
          ),
        );
      });
      return;
    }
    useCameraMeasurementResult(ref, result);
    context.pop(result);
  }

  double? _selectedDistanceM(double? fieldDistanceM) {
    final manualDistance = double.tryParse(
      _manualDistanceController.text.trim(),
    );
    if (manualDistance != null && manualDistance > 0) {
      return manualDistance;
    }
    return fieldDistanceM != null && fieldDistanceM > 0 ? fieldDistanceM : null;
  }

  String _selectedDistanceSource(double? fieldDistanceM) {
    final manualDistance = double.tryParse(
      _manualDistanceController.text.trim(),
    );
    if (manualDistance != null && manualDistance > 0) {
      return 'manual_input';
    }
    return fieldDistanceM != null && fieldDistanceM > 0
        ? 'gps_walk_measurement'
        : 'unavailable';
  }

  double? _selectedCameraHeightM() {
    final cameraHeight = double.tryParse(_cameraHeightController.text.trim());
    return cameraHeight != null && cameraHeight > 0 ? cameraHeight : null;
  }

  double _radiansToDegrees(double radians) => radians * 180 / pi;

  String _reliability(String distanceSource) {
    return switch (distanceSource) {
      'manual_input' => 'Manual distance',
      'gps_walk_measurement' => 'Fair',
      _ => 'Needs distance',
    };
  }
}

class _LiveLine {
  const _LiveLine({required this.first, required this.second});

  final Offset first;
  final Offset second;
}

class _MeasurementHeroHeader extends StatelessWidget {
  const _MeasurementHeroHeader({required this.type, required this.hasDistance});

  final _CameraMeasurementType type;
  final bool hasDistance;

  @override
  Widget build(BuildContext context) {
    final isHeight = type == _CameraMeasurementType.treeHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            text: isHeight ? 'MEASURE ' : 'MEASURE ',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textDark,
              letterSpacing: 0,
            ),
            children: [
              TextSpan(
                text: isHeight ? 'HEIGHT' : 'WIDTH',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.successGreen,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          isHeight
              ? 'Point at the tree base, then move the phone upward.'
              : 'Point at one canopy edge, then pan the phone sideways.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: hasDistance
                ? AppColors.successGreen.withValues(alpha: 0.18)
                : AppColors.warningOrange.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hasDistance
                  ? AppColors.successGreen
                  : AppColors.warningOrange,
            ),
          ),
          child: Text(
            hasDistance
                ? 'Distance ready for meter estimate'
                : 'Add distance to show meters',
            style: AppTextStyles.labelLarge.copyWith(
              color: hasDistance
                  ? AppColors.successGreen
                  : AppColors.warningOrange,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveStatusStrip extends StatelessWidget {
  const _LiveStatusStrip({
    required this.text,
    required this.isTracking,
    required this.hasDistance,
  });

  final String text;
  final bool isTracking;
  final bool hasDistance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isTracking
                ? Icons.sensors_rounded
                : hasDistance
                ? Icons.straighten_rounded
                : Icons.info_outline_rounded,
            color: isTracking
                ? AppColors.successGreen
                : hasDistance
                ? AppColors.primaryDarkGreen
                : AppColors.warningOrange,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryDarkGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.type, required this.onSelected});

  final _CameraMeasurementType type;
  final ValueChanged<_CameraMeasurementType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeButton(
            label: 'Tree Height',
            icon: Icons.height_rounded,
            isSelected: type == _CameraMeasurementType.treeHeight,
            onTap: () => onSelected(_CameraMeasurementType.treeHeight),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _TypeButton(
            label: 'Canopy Width',
            icon: Icons.width_wide_rounded,
            isSelected: type == _CameraMeasurementType.canopyWidth,
            onTap: () => onSelected(_CameraMeasurementType.canopyWidth),
          ),
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderSoft,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDarkGreen.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.white : AppColors.successGreen,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge.copyWith(
                color: isSelected ? AppColors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureModeSelector extends StatelessWidget {
  const _CaptureModeSelector({required this.mode, required this.onSelected});

  final _CameraCaptureMode mode;
  final ValueChanged<_CameraCaptureMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final isExtended = mode == _CameraCaptureMode.extendedSweep;

    return SilvamangCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Measurement mode', style: AppTextStyles.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_CameraCaptureMode>(
              segments: const [
                ButtonSegment(
                  value: _CameraCaptureMode.normal,
                  icon: Icon(Icons.open_with_rounded),
                  label: Text('Normal'),
                ),
                ButtonSegment(
                  value: _CameraCaptureMode.extendedSweep,
                  icon: Icon(Icons.unfold_more_rounded),
                  label: Text('Extended'),
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onSelected(selection.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.white
                      : AppColors.primaryDarkGreen,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.primaryGreen
                      : AppColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isExtended
                ? 'Sweep continuously from the base to the top, then lock while steady.'
                : 'Start at the base and move the phone upward in one pass.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DistanceGuidanceBanner extends StatelessWidget {
  const _DistanceGuidanceBanner({
    required this.type,
    required this.mode,
    required this.distanceM,
    required this.result,
    required this.isTracking,
    required this.orientationStable,
    required this.stabilityProgress,
    required this.currentElevationDegrees,
  });

  final _CameraMeasurementType type;
  final _CameraCaptureMode mode;
  final double? distanceM;
  final CameraMeasurementResult? result;
  final bool isTracking;
  final bool orientationStable;
  final double stabilityProgress;
  final double? currentElevationDegrees;

  @override
  Widget build(BuildContext context) {
    final isExtended =
        type == _CameraMeasurementType.treeHeight &&
        mode == _CameraCaptureMode.extendedSweep;
    final isTooClose = result != null && !result!.qualityAccepted;

    late final String title;
    late final String message;
    late final IconData icon;
    late final Color color;

    if (distanceM == null || distanceM! <= 0) {
      title = 'Distance required';
      message = 'Measure or enter your distance from the trunk first.';
      icon = Icons.straighten_rounded;
      color = AppColors.warningOrange;
    } else if (isTooClose) {
      final recommended = result!.recommendedDistanceM;
      title = 'Too Close';
      message = recommended != null && recommended.isFinite
          ? 'Current: ${distanceM!.toStringAsFixed(1)} m. Move back to at least ${recommended.toStringAsFixed(1)} m, update the distance, and measure again.'
          : 'Move farther from the tree, update the distance, and measure again.';
      icon = Icons.social_distance_rounded;
      color = AppColors.warningOrange;
    } else if (isExtended && isTracking) {
      title = orientationStable ? 'Ready to lock' : 'Extended sweep active';
      message = orientationStable
          ? 'Keep the crosshair on the tree top and lock the height.'
          : 'Move toward the top, then hold briefly for Quick Hold.';
      icon = orientationStable
          ? Icons.lock_outline_rounded
          : Icons.unfold_more_rounded;
      color = orientationStable
          ? AppColors.successGreen
          : AppColors.primaryGreen;
    } else if (result != null) {
      final angle = result!.viewingAngleDegrees ?? result!.angularSpanDegrees;
      title = 'Good measuring position';
      message = angle == null
          ? 'Distance: ${distanceM!.toStringAsFixed(1)} m.'
          : 'Distance: ${distanceM!.toStringAsFixed(1)} m. Angle: ${angle.toStringAsFixed(1)} degrees.';
      icon = Icons.check_circle_outline_rounded;
      color = AppColors.successGreen;
    } else if (isExtended && !orientationStable) {
      title = 'Quick Hold';
      message = 'Keep the crosshair on the tree base for a moment.';
      icon = Icons.screen_lock_rotation_rounded;
      color = AppColors.warningOrange;
    } else if (isExtended) {
      title = 'Ready for extended sweep';
      message = currentElevationDegrees == null
          ? 'Distance: ${distanceM!.toStringAsFixed(1)} m.'
          : 'Distance: ${distanceM!.toStringAsFixed(1)} m. Phone angle: ${currentElevationDegrees!.toStringAsFixed(1)} degrees.';
      icon = Icons.center_focus_strong_rounded;
      color = AppColors.successGreen;
    } else {
      title = 'Distance ready';
      message =
          'Standing distance: ${distanceM!.toStringAsFixed(1)} m. Keep the movement slow and steady.';
      icon = Icons.straighten_rounded;
      color = AppColors.primaryGreen;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(color: color),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: AppTextStyles.bodySmall),
                if (isExtended && !orientationStable) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: stabilityProgress,
                      minHeight: 5,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.16),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMeasurementInstructionCard extends StatelessWidget {
  const _LiveMeasurementInstructionCard({
    required this.type,
    required this.mode,
  });

  final _CameraMeasurementType type;
  final _CameraCaptureMode mode;

  @override
  Widget build(BuildContext context) {
    final isHeight = type == _CameraMeasurementType.treeHeight;
    final isExtended = isHeight && mode == _CameraCaptureMode.extendedSweep;
    final actionText = isExtended
        ? 'Use one extended sweep'
        : isHeight
        ? 'Move phone up'
        : 'Pan phone sideways';
    final detailText = isExtended
        ? 'Start at the trunk base, move continuously to the highest point, then lock.'
        : isHeight
        ? 'Point at the tree base, start live height, then move the phone upward.'
        : 'Point at one canopy edge, start live width, then pan to the other edge.';
    final tipText = isExtended
        ? 'Keep the same standing position and hold steady before starting and locking.'
        : isHeight
        ? 'Keep the tree fully visible and move the phone steadily upward.'
        : 'Keep the canopy fully visible and pan the phone steadily sideways.';

    return SilvamangCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryDarkGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isExtended
                      ? Icons.unfold_more_rounded
                      : isHeight
                      ? Icons.keyboard_double_arrow_up_rounded
                      : Icons.swap_horiz_rounded,
                  color: AppColors.successGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actionText, style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(detailText, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _InstructionStep(
                number: '1',
                icon: Icons.center_focus_strong_rounded,
                text: isHeight ? 'Aim at base' : 'Point at edge',
              ),
              _InstructionStep(
                number: '2',
                icon: isExtended
                    ? Icons.north_rounded
                    : isHeight
                    ? Icons.north_rounded
                    : Icons.swap_horiz_rounded,
                text: isExtended
                    ? 'Sweep upward'
                    : isHeight
                    ? 'Move phone up'
                    : 'Pan sideways',
              ),
              _InstructionStep(
                number: '3',
                icon: isExtended
                    ? Icons.lock_outline_rounded
                    : Icons.straighten_rounded,
                text: isExtended ? 'Hold and lock' : 'Watch live value',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.successGreen,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tipText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryDarkGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.number,
    required this.icon,
    required this.text,
  });

  final String number;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Icon(icon, color: AppColors.primaryDarkGreen, size: 21),
              ),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.successGreen,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            text,
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.engineStatus,
    required this.distanceM,
    required this.distanceSource,
    required this.cameraStatus,
    required this.livePointingStatus,
  });

  final String engineStatus;
  final double? distanceM;
  final String distanceSource;
  final String? cameraStatus;
  final String livePointingStatus;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SilvamangBadge(label: 'Prototype', type: SilvamangBadgeType.info),
              SilvamangBadge(
                label: 'Orientation measurement',
                type: SilvamangBadgeType.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(label: 'Engine status', value: engineStatus),
          _DetailRow(
            label: 'Distance source',
            value: _distanceSourceLabel(distanceSource),
          ),
          _DetailRow(
            label: 'Distance',
            value: distanceM == null
                ? 'Field or manual distance is required for meter estimate.'
                : '${distanceM!.toStringAsFixed(2)} m',
          ),
          if (cameraStatus != null)
            _DetailRow(label: 'Camera status', value: cameraStatus!),
          _DetailRow(label: 'Live pointing', value: livePointingStatus),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryDarkGreen,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MeasurementGuideOverlay extends StatelessWidget {
  const _MeasurementGuideOverlay({required this.type});

  final _CameraMeasurementType type;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _MeasurementGuidePainter(type: type)),
    );
  }
}

class _MeasurementGuidePainter extends CustomPainter {
  const _MeasurementGuidePainter({required this.type});

  final _CameraMeasurementType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (type == _CameraMeasurementType.treeHeight) {
      canvas.drawLine(
        Offset(size.width / 2, size.height * 0.18),
        Offset(size.width / 2, size.height * 0.82),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(size.width * 0.18, size.height / 2),
        Offset(size.width * 0.82, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeasurementGuidePainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

class _PointMarkerOverlay extends StatelessWidget {
  const _PointMarkerOverlay({
    required this.type,
    this.basePoint,
    this.topPoint,
    this.leftEdgePoint,
    this.rightEdgePoint,
  });

  final _CameraMeasurementType type;
  final CameraMeasurementPoint? basePoint;
  final CameraMeasurementPoint? topPoint;
  final CameraMeasurementPoint? leftEdgePoint;
  final CameraMeasurementPoint? rightEdgePoint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PointMarkerPainter(
          type: type,
          firstPoint: type == _CameraMeasurementType.treeHeight
              ? basePoint
              : leftEdgePoint,
          secondPoint: type == _CameraMeasurementType.treeHeight
              ? topPoint
              : rightEdgePoint,
        ),
      ),
    );
  }
}

class _PointMarkerPainter extends CustomPainter {
  const _PointMarkerPainter({
    required this.type,
    required this.firstPoint,
    required this.secondPoint,
  });

  final _CameraMeasurementType type;
  final CameraMeasurementPoint? firstPoint;
  final CameraMeasurementPoint? secondPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final first = firstPoint == null
        ? null
        : Offset(
            firstPoint!.frameCenterX * size.width,
            firstPoint!.frameCenterY * size.height,
          );
    final second = secondPoint == null
        ? null
        : Offset(
            secondPoint!.frameCenterX * size.width,
            secondPoint!.frameCenterY * size.height,
          );

    if (first != null && second != null) {
      final linePaint = Paint()
        ..color = AppColors.warningOrange
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(first, second, linePaint);
    }

    if (first != null) {
      _drawPoint(
        canvas,
        first,
        type == _CameraMeasurementType.treeHeight ? 'Base' : 'Left',
      );
    }
    if (second != null) {
      _drawPoint(
        canvas,
        second,
        type == _CameraMeasurementType.treeHeight ? 'Top' : 'Right',
      );
    }
  }

  void _drawPoint(Canvas canvas, Offset point, String label) {
    final fill = Paint()..color = AppColors.primaryGreen;
    final stroke = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(point, 12, fill);
    canvas.drawCircle(point, 12, stroke);
  }

  @override
  bool shouldRepaint(covariant _PointMarkerPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.firstPoint != firstPoint ||
        oldDelegate.secondPoint != secondPoint;
  }
}

class _CrosshairOverlay extends StatelessWidget {
  const _CrosshairOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _CrosshairPainter()));
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = AppColors.primaryDarkGreen.withValues(alpha: 0.55)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center.translate(-28, 0), center.translate(28, 0), shadow);
    canvas.drawLine(center.translate(0, -28), center.translate(0, 28), shadow);
    canvas.drawLine(center.translate(-28, 0), center.translate(28, 0), paint);
    canvas.drawLine(center.translate(0, -28), center.translate(0, 28), paint);
    canvas.drawCircle(center, 7, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraModeRail extends StatelessWidget {
  const _CameraModeRail({required this.type, required this.onSelected});

  final _CameraMeasurementType type;
  final ValueChanged<_CameraMeasurementType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailModeButton(
            label: 'Height',
            icon: Icons.height_rounded,
            isSelected: type == _CameraMeasurementType.treeHeight,
            onTap: () => onSelected(_CameraMeasurementType.treeHeight),
          ),
          const SizedBox(height: AppSpacing.xs),
          _RailModeButton(
            label: 'Width',
            icon: Icons.swap_horiz_rounded,
            isSelected: type == _CameraMeasurementType.canopyWidth,
            onTap: () => onSelected(_CameraMeasurementType.canopyWidth),
          ),
        ],
      ),
    );
  }
}

class _RailModeButton extends StatelessWidget {
  const _RailModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.successGreen.withValues(alpha: 0.24)
              : AppColors.softGreen.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.successGreen : AppColors.borderSoft,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primaryDarkGreen
                  : AppColors.primaryGreen,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryDarkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraLiveControls extends StatelessWidget {
  const _CameraLiveControls({
    required this.actionText,
    this.actionIcon,
    required this.isTracking,
    required this.canStart,
    required this.canUseResult,
    required this.onToggle,
    required this.onReset,
    required this.onUseResult,
  });

  final String actionText;
  final IconData? actionIcon;
  final bool isTracking;
  final bool canStart;
  final bool canUseResult;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final VoidCallback? onUseResult;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _RoundCameraButton(
            icon: Icons.close_rounded,
            label: 'Reset',
            onTap: onReset,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: canStart ? onToggle : null,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canStart
                      ? AppColors.successGreen
                      : AppColors.softGreen,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: canStart
                      ? [
                          BoxShadow(
                            color: AppColors.successGreen.withValues(
                              alpha: 0.34,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      actionIcon ??
                          (isTracking
                              ? Icons.check_rounded
                              : Icons.center_focus_strong_rounded),
                      color: AppColors.white,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        actionText,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RoundCameraButton(
            icon: Icons.check_rounded,
            label: 'Use',
            onTap: canUseResult ? onUseResult : null,
          ),
        ],
      ),
    );
  }
}

class _RoundCameraButton extends StatelessWidget {
  const _RoundCameraButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.softGreen
                    : AppColors.borderSoft.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Icon(
                icon,
                color: enabled
                    ? AppColors.primaryDarkGreen
                    : AppColors.mutedText.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: enabled
                    ? AppColors.primaryDarkGreen
                    : AppColors.mutedText.withValues(alpha: 0.52),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveMeasurementOverlay extends StatelessWidget {
  const _LiveMeasurementOverlay({
    required this.type,
    required this.mode,
    required this.start,
    required this.end,
    required this.result,
    required this.hasDistanceReference,
    required this.isDragging,
  });

  final _CameraMeasurementType type;
  final _CameraCaptureMode mode;
  final Offset? start;
  final Offset? end;
  final CameraMeasurementResult? result;
  final bool hasDistanceReference;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LiveMeasurementPainter(
                type: type,
                start: start,
                end: end,
                isActive: start != null && end != null,
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 96,
            child: _LiveGestureHint(
              type: type,
              mode: mode,
              hasDistanceReference: hasDistanceReference,
              isDragging: isDragging,
              result: result,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMeasurementPainter extends CustomPainter {
  const _LiveMeasurementPainter({
    required this.type,
    required this.start,
    required this.end,
    required this.isActive,
  });

  final _CameraMeasurementType type;
  final Offset? start;
  final Offset? end;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final first = _toCanvasPoint(
      start ??
          (type == _CameraMeasurementType.treeHeight
              ? const Offset(0.5, 0.78)
              : const Offset(0.22, 0.5)),
      size,
    );
    final second = _toCanvasPoint(
      end ??
          (type == _CameraMeasurementType.treeHeight
              ? const Offset(0.5, 0.25)
              : const Offset(0.78, 0.5)),
      size,
    );

    final guidePaint = Paint()
      ..color = AppColors.white.withValues(alpha: isActive ? 0.76 : 0.48)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final linePaint = Paint()
      ..color = isActive
          ? AppColors.successGreen
          : AppColors.successGreen.withValues(alpha: 0.55)
      ..strokeWidth = isActive ? 4 : 3
      ..strokeCap = StrokeCap.round;

    if (type == _CameraMeasurementType.treeHeight) {
      _drawDashedLine(
        canvas,
        Offset(first.dx - 70, first.dy),
        Offset(first.dx + 70, first.dy),
        guidePaint,
      );
      _drawDashedLine(
        canvas,
        Offset(second.dx - 70, second.dy),
        Offset(second.dx + 70, second.dy),
        guidePaint,
      );
    } else {
      _drawDashedLine(
        canvas,
        Offset(first.dx, first.dy - 70),
        Offset(first.dx, first.dy + 70),
        guidePaint,
      );
      _drawDashedLine(
        canvas,
        Offset(second.dx, second.dy - 70),
        Offset(second.dx, second.dy + 70),
        guidePaint,
      );
    }

    canvas.drawLine(first, second, linePaint);
    _drawHandle(canvas, first, isActive);
    _drawHandle(canvas, second, isActive);
  }

  Offset _toCanvasPoint(Offset normalized, Size size) {
    return Offset(normalized.dx * size.width, normalized.dy * size.height);
  }

  void _drawHandle(Canvas canvas, Offset point, bool isActive) {
    final fill = Paint()
      ..color = isActive ? AppColors.successGreen : AppColors.primaryDarkGreen;
    final stroke = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(point, isActive ? 13 : 11, fill);
    canvas.drawCircle(point, isActive ? 13 : 11, stroke);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final distance = (end - start).distance;
    if (distance <= 0) {
      return;
    }

    final direction = (end - start) / distance;
    var current = 0.0;
    while (current < distance) {
      final next = min(current + dashWidth, distance);
      canvas.drawLine(
        start + direction * current,
        start + direction * next,
        paint,
      );
      current += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _LiveMeasurementPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.isActive != isActive;
  }
}

class _LiveTopOverlay extends StatelessWidget {
  const _LiveTopOverlay({
    required this.stepLabel,
    required this.instruction,
    required this.type,
    required this.result,
    required this.hasDistanceReference,
  });

  final String stepLabel;
  final String instruction;
  final _CameraMeasurementType type;
  final CameraMeasurementResult? result;
  final bool hasDistanceReference;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StepCard(stepLabel: stepLabel, instruction: instruction),
        ),
        const SizedBox(width: AppSpacing.sm),
        _LiveMetricBadge(
          type: type,
          result: result,
          hasDistanceReference: hasDistanceReference,
        ),
      ],
    );
  }
}

class _LiveMetricBadge extends StatelessWidget {
  const _LiveMetricBadge({
    required this.type,
    required this.result,
    required this.hasDistanceReference,
  });

  final _CameraMeasurementType type;
  final CameraMeasurementResult? result;
  final bool hasDistanceReference;

  @override
  Widget build(BuildContext context) {
    final value = result == null
        ? '--'
        : result!.estimatedValueM.toStringAsFixed(2);
    final subtitle = result != null && !result!.qualityAccepted
        ? 'TOO CLOSE'
        : !hasDistanceReference
        ? 'SET DISTANCE'
        : type == _CameraMeasurementType.treeHeight
        ? 'LIVE HEIGHT'
        : 'LIVE WIDTH';

    return Container(
      width: 118,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              text: value,
              style: AppTextStyles.metricValue.copyWith(
                color: AppColors.primaryDarkGreen,
                fontSize: 28,
              ),
              children: [
                if (result != null)
                  TextSpan(
                    text: ' m',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primaryDarkGreen,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LiveGestureHint extends StatelessWidget {
  const _LiveGestureHint({
    required this.type,
    required this.mode,
    required this.hasDistanceReference,
    required this.isDragging,
    required this.result,
  });

  final _CameraMeasurementType type;
  final _CameraCaptureMode mode;
  final bool hasDistanceReference;
  final bool isDragging;
  final CameraMeasurementResult? result;

  @override
  Widget build(BuildContext context) {
    final isHeight = type == _CameraMeasurementType.treeHeight;
    final isExtended = isHeight && mode == _CameraCaptureMode.extendedSweep;
    final title = isExtended
        ? 'EXTENDED SWEEP TO TOP'
        : isHeight
        ? 'MOVE PHONE UP'
        : 'PAN PHONE SIDEWAYS';
    final body = isExtended
        ? 'move continuously, then hold steady at the highest point'
        : isHeight
        ? 'from the base toward the top of the object'
        : 'from one edge toward the other edge';
    final status = result != null && !result!.qualityAccepted
        ? 'Too close. Follow the distance guide.'
        : result != null
        ? 'Measurement ready'
        : hasDistanceReference
        ? isExtended
              ? 'Keep the same standing position'
              : 'Keep moving steadily'
        : 'Add distance for meter value';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDragging ? AppColors.successGreen : AppColors.borderSoft,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Icon(
              isExtended
                  ? Icons.unfold_more_rounded
                  : isHeight
                  ? Icons.north_rounded
                  : Icons.swap_horiz_rounded,
              color: AppColors.successGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.successGreen,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  status,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.stepLabel, required this.instruction});

  final String stepLabel;
  final String instruction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stepLabel,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.successGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            instruction,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}

class _DistanceInputCard extends StatelessWidget {
  const _DistanceInputCard({
    required this.type,
    required this.fieldDistanceAvailable,
    required this.fieldDistanceM,
    required this.manualDistanceController,
    required this.cameraHeightController,
    required this.onMeasureDistance,
  });

  final _CameraMeasurementType type;
  final bool fieldDistanceAvailable;
  final double? fieldDistanceM;
  final TextEditingController manualDistanceController;
  final TextEditingController cameraHeightController;
  final VoidCallback onMeasureDistance;

  @override
  Widget build(BuildContext context) {
    final fieldDistanceText = fieldDistanceM == null
        ? 'Not measured'
        : '${fieldDistanceM!.toStringAsFixed(2)} meters';

    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.social_distance_rounded,
                  color: AppColors.primaryDarkGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance for accuracy',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Use Field Distance Meter or enter the phone-to-mangrove distance. Species identification can still continue without measurement.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(label: 'Field distance', value: fieldDistanceText),
          const SizedBox(height: AppSpacing.md),
          _NumberField(
            controller: manualDistanceController,
            label: 'Manual distance (meters)',
            hint: fieldDistanceAvailable
                ? 'Leave blank to use Field Distance Meter'
                : 'Example: 5',
            icon: Icons.social_distance_rounded,
          ),
          if (type == _CameraMeasurementType.treeHeight) ...[
            const SizedBox(height: AppSpacing.md),
            _NumberField(
              controller: cameraHeightController,
              label: 'Phone/eye height (meters)',
              hint: 'Example: 1.5',
              icon: Icons.accessibility_new_rounded,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SilvamangButton(
            text: fieldDistanceAvailable
                ? 'Update Field Distance'
                : 'Measure Field Distance',
            icon: Icons.my_location_rounded,
            type: SilvamangButtonType.outline,
            fullWidth: false,
            onPressed: onMeasureDistance,
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _PointSummary extends StatelessWidget {
  const _PointSummary({
    required this.type,
    this.basePoint,
    this.topPoint,
    this.leftEdgePoint,
    this.rightEdgePoint,
  });

  final _CameraMeasurementType type;
  final CameraMeasurementPoint? basePoint;
  final CameraMeasurementPoint? topPoint;
  final CameraMeasurementPoint? leftEdgePoint;
  final CameraMeasurementPoint? rightEdgePoint;

  @override
  Widget build(BuildContext context) {
    final first = type == _CameraMeasurementType.treeHeight
        ? basePoint
        : leftEdgePoint;
    final second = type == _CameraMeasurementType.treeHeight
        ? topPoint
        : rightEdgePoint;

    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Captured point summary', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _PointRow(
            label: type == _CameraMeasurementType.treeHeight
                ? 'Base'
                : 'Left edge',
            point: first,
          ),
          _PointRow(
            label: type == _CameraMeasurementType.treeHeight
                ? 'Top'
                : 'Right edge',
            point: second,
          ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.label, required this.point});

  final String label;
  final CameraMeasurementPoint? point;

  @override
  Widget build(BuildContext context) {
    final selectedPoint = point;
    final pointText = selectedPoint == null
        ? 'Not set'
        : '${selectedPoint.timestamp.toLocal()} | ${selectedPoint.locationStatus}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: AppTextStyles.metricLabel),
          ),
          Expanded(child: Text(pointText, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _CameraResultCard extends StatelessWidget {
  const _CameraResultCard({required this.result, required this.onUseResult});

  final CameraMeasurementResult result;
  final VoidCallback? onUseResult;

  @override
  Widget build(BuildContext context) {
    final isHeight = result.measurementType == 'tree_height';
    final title = isHeight ? 'Estimated Height' : 'Estimated Canopy Width';
    final icon = isHeight ? Icons.park_rounded : Icons.forest_rounded;
    final statusColor = result.qualityAccepted
        ? AppColors.successGreen
        : AppColors.warningOrange;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Measurement Results',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.successGreen,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ResultMetricPanel(
            title: title,
            icon: icon,
            value: result.estimatedValueM,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.softGreen.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              children: [
                _DarkDetailRow(label: 'Method', value: result.methodUsed),
                _DarkDetailRow(
                  label: 'Mode',
                  value: result.measurementMode == 'extended_sweep'
                      ? 'Extended Sweep'
                      : 'Normal',
                ),
                _DarkDetailRow(label: 'Reliability', value: result.reliability),
                _DarkDetailRow(
                  label: 'Distance source',
                  value: _distanceSourceLabel(result.distanceSource),
                ),
                _DarkDetailRow(
                  label: 'Distance',
                  value: '${result.distanceM.toStringAsFixed(2)} m',
                ),
                if (result.angularSpanDegrees != null)
                  _DarkDetailRow(
                    label: 'Angle span',
                    value:
                        '${result.angularSpanDegrees!.toStringAsFixed(1)} degrees',
                  ),
                if (result.viewingAngleDegrees != null)
                  _DarkDetailRow(
                    label: 'Top angle',
                    value:
                        '${result.viewingAngleDegrees!.toStringAsFixed(1)} degrees',
                  ),
                if (result.recommendedDistanceM != null)
                  _DarkDetailRow(
                    label: 'Recommended',
                    value:
                        '${result.recommendedDistanceM!.toStringAsFixed(1)} m or farther',
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.38)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  result.qualityAccepted
                      ? Icons.info_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: statusColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    result.warningMessage,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SilvamangButton(
            text: result.qualityAccepted
                ? 'Use Result'
                : 'Move Back and Remeasure',
            icon: result.qualityAccepted
                ? Icons.check_circle_rounded
                : Icons.social_distance_rounded,
            onPressed: onUseResult,
          ),
        ],
      ),
    );
  }
}

class _ResultMetricPanel extends StatelessWidget {
  const _ResultMetricPanel({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.successGreen, size: 42),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  TextSpan(
                    text: value.toStringAsFixed(2),
                    style: AppTextStyles.metricValue.copyWith(
                      color: AppColors.successGreen,
                      fontSize: 40,
                    ),
                    children: [
                      TextSpan(
                        text: ' m',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.primaryDarkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkDetailRow extends StatelessWidget {
  const _DarkDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: AppTextStyles.metricLabel.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primaryDarkGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrototypeWarningCard extends StatelessWidget {
  const _PrototypeWarningCard();

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryDarkGreen,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Live measurement needs a real phone-to-mangrove distance for meter values. If distance is unavailable, continue with species identification only.',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: AppTextStyles.metricLabel),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

String _distanceSourceLabel(String source) {
  return switch (source) {
    'gps_walk_measurement' => 'Field Distance Meter',
    'manual_input' => 'Manual distance',
    _ => 'Unavailable',
  };
}
