import '../../../../shared/widgets/structural_measurement_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../identification/presentation/controllers/identification_controller.dart';
import '../../../location_validation/presentation/controllers/location_controller.dart';
import '../../../measurements/data/models/camera_measurement_result.dart';
import '../controllers/capture_controller.dart';

class ManualSpeciesMeasurementPage extends ConsumerStatefulWidget {
  const ManualSpeciesMeasurementPage({
    super.key,
    required this.scientificName,
    required this.commonName,
    this.transectLocalId,
  });

  final String scientificName;
  final String commonName;
  final String? transectLocalId;

  @override
  ConsumerState<ManualSpeciesMeasurementPage> createState() =>
      _ManualSpeciesMeasurementPageState();
}

class _ManualSpeciesMeasurementPageState
    extends ConsumerState<ManualSpeciesMeasurementPage> {
  final _formKey = GlobalKey<FormState>();
  final _height = TextEditingController();
  final _width = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  Map<String, double?> _structural = {};
  final _plot = TextEditingController();
  bool _saving = false;
  bool _heightFromCamera = false;
  bool _widthFromCamera = false;
  bool _heightConfirmed = false;
  bool _widthConfirmed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(locationControllerProvider.notifier).captureScanLocation();
      }
    });
  }

  @override
  void dispose() {
    _plot.dispose();
    _height.dispose();
    _width.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _measure(String type) async {
    final result = await context.pushNamed<CameraMeasurementResult>(
      RouteNames.cameraPointingMeasurement,
      queryParameters: {'type': type},
    );
    if (!mounted ||
        result == null ||
        !result.qualityAccepted ||
        !result.estimatedValueM.isFinite ||
        result.estimatedValueM <= 0) {
      return;
    }
    setState(() {
      if (type == 'tree_height') {
        _height.text = result.estimatedValueM.toStringAsFixed(2);
        _heightFromCamera = true;
        _heightConfirmed = true;
      } else {
        _width.text = result.estimatedValueM.toStringAsFixed(2);
        _widthFromCamera = true;
        _widthConfirmed = true;
      }
    });
  }

  String? _positiveNumber(String? value) {
    final number = double.tryParse((value ?? '').trim());
    return number != null && number.isFinite && number > 0
        ? null
        : 'Enter a value greater than zero.';
  }

  void _confirmMeasurement({required bool height}) {
    final controller = height ? _height : _width;
    final error = _positiveNumber(controller.text);
    if (error != null) {
      _showError(error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      if (height) {
        _heightConfirmed = true;
      } else {
        _widthConfirmed = true;
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    if (!_heightConfirmed || _positiveNumber(_height.text) != null) {
      _showError('Confirm height before saving. Canopy width is optional.');
      return;
    }
    final location = ref.read(locationControllerProvider);
    final latText = _latitude.text.trim();
    final lonText = _longitude.text.trim();
    final hasManualCoordinates = latText.isNotEmpty || lonText.isNotEmpty;
    final lat = hasManualCoordinates
        ? double.tryParse(latText)
        : location.latitude;
    final lon = hasManualCoordinates
        ? double.tryParse(lonText)
        : location.longitude;
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      _showError('Get GPS location or enter valid latitude and longitude.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(identificationControllerProvider.notifier)
          .saveManualObservation(
            scientificName: widget.scientificName,
            commonName: widget.commonName,
            transectLocalId: widget.transectLocalId,
            capturedImages: ref.read(captureControllerProvider).capturedImages,
            gbhCm: _structural['gbh_cm'],
            dbhCm: _structural['dbh_cm'],
            canopy1M: _structural['canopy_1_m'],
            canopy2M: _structural['canopy_2_m'],
            plotNo: _plot.text.trim().isEmpty ? null : _plot.text.trim(),
            heightM: double.parse(_height.text.trim()),
            canopyWidthM: double.tryParse(_width.text.trim()) ?? double.nan,
            measurementMethod: _heightFromCamera || _widthFromCamera
                ? 'camera_pointing_and_manual'
                : 'manual_input',
            latitude: lat,
            longitude: lon,
            locationName: hasManualCoordinates
                ? 'Manual coordinates'
                : location.locationName,
            address: hasManualCoordinates ? '' : location.address,
            barangay: hasManualCoordinates ? null : location.barangay,
            manualBarangay: location.manualBarangay,
            locationAccuracy: hasManualCoordinates ? null : location.accuracy,
            locationCapturedAt: hasManualCoordinates
                ? DateTime.now()
                : location.timestamp,
            barangayStatus: hasManualCoordinates
                ? 'Manual coordinates'
                : location.barangayStatus,
            locationSource: hasManualCoordinates
                ? 'manual'
                : location.barangaySource,
          );
      if (!mounted) return;
      final result = ref.read(identificationControllerProvider);
      if (result.errorMessage != null) {
        _showError(result.errorMessage!);
      } else if (result.successMessage != null) {
        _showError(result.successMessage!);
        if (widget.transectLocalId == null) {
          context.goNamed(RouteNames.records);
        } else {
          context.goNamed(
            RouteNames.transectDetail,
            pathParameters: {'id': widget.transectLocalId!},
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _showError('Could not save the observation. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('Measure Mangrove'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.scientificName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (widget.commonName.isNotEmpty) Text(widget.commonName),
                    const SizedBox(height: 8),
                    const Text(
                      'Photos are optional for a manually entered species.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _plot,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Plot No (optional)',
                      ),
                    ),
                    StructuralMeasurementFields(
                      onChanged: (values) => _structural = values,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Structural Measurements',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_heightConfirmed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryGreen,
                        ),
                        title: const Text('Tree height'),
                        subtitle: Text('${_height.text.trim()} m'),
                        trailing: TextButton(
                          onPressed: () =>
                              setState(() => _heightConfirmed = false),
                          child: const Text('Edit'),
                        ),
                      )
                    else ...[
                      TextFormField(
                        controller: _height,
                        decoration: const InputDecoration(
                          labelText: 'Tree height (m)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => _heightFromCamera = false,
                      ),
                      TextButton.icon(
                        onPressed: () => _measure('tree_height'),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Measure height with camera'),
                      ),
                      SilvamangButton(
                        text: 'Confirm Height',
                        icon: Icons.check_rounded,
                        onPressed: () => _confirmMeasurement(height: true),
                      ),
                    ],
                    if (_heightConfirmed) ...[
                      const Divider(height: 24),
                      if (_widthConfirmed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primaryGreen,
                          ),
                          title: const Text('Canopy width'),
                          subtitle: Text('${_width.text.trim()} m'),
                          trailing: TextButton(
                            onPressed: () =>
                                setState(() => _widthConfirmed = false),
                            child: const Text('Edit'),
                          ),
                        )
                      else ...[
                        TextFormField(
                          controller: _width,
                          decoration: const InputDecoration(
                            labelText: 'Canopy width (m, optional)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          onChanged: (_) => _widthFromCamera = false,
                        ),
                        TextButton.icon(
                          onPressed: () => _measure('canopy_width'),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Measure width with camera'),
                        ),
                        SilvamangButton(
                          text: 'Confirm Width',
                          icon: Icons.check_rounded,
                          onPressed: () => _confirmMeasurement(height: false),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      location.hasLocation
                          ? '${location.latitude!.toStringAsFixed(6)}, ${location.longitude!.toStringAsFixed(6)}'
                          : location.statusMessage,
                    ),
                    TextButton.icon(
                      onPressed: location.isLoading
                          ? null
                          : () => ref
                                .read(locationControllerProvider.notifier)
                                .captureScanLocation(),
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Get GPS location'),
                    ),
                    const Text('If GPS is unavailable, enter coordinates:'),
                    TextField(
                      controller: _latitude,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                    TextField(
                      controller: _longitude,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_heightConfirmed) ...[
              const SizedBox(height: 20),
              SilvamangButton(
                text: 'Save Observation',
                icon: Icons.save_rounded,
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
