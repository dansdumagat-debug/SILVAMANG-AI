import '../../../../shared/widgets/structural_measurement_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../identification/presentation/controllers/identification_controller.dart';
import '../../../location_validation/presentation/controllers/location_controller.dart';
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
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  Map<String, double?> _structural = {};
  final _plot = TextEditingController();
  bool _saving = false;
  bool _measurementsConfirmed = false;
  bool _usedCamera = false;

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
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    if (!_measurementsConfirmed || _structural['height_m'] == null) {
      _showError('Confirm your structural measurements before saving.');
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
    if (hasManualCoordinates &&
        (lat == null ||
            lon == null ||
            !lat.isFinite ||
            !lon.isFinite ||
            lat < -90 ||
            lat > 90 ||
            lon < -180 ||
            lon > 180)) {
      _showError(
        'Enter both valid latitude and longitude, or leave both blank.',
      );
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
            canopy1M: _structural['canopy_1_m'],
            canopy2M: _structural['canopy_2_m'],
            plotNo: _plot.text.trim().isEmpty ? null : _plot.text.trim(),
            heightM: _structural['height_m']!,
            canopyWidthM: double.nan,
            measurementMethod: _usedCamera
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
                      requireHeight: true,
                      onChanged: (values) => _structural = values,
                      onConfirmed: (value) =>
                          setState(() => _measurementsConfirmed = value),
                      onCameraUsed: () => _usedCamera = true,
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
                      'Location (optional)',
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
                    const Text(
                      'You can save without location validation. Coordinates are optional:',
                    ),
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
            ...[
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
