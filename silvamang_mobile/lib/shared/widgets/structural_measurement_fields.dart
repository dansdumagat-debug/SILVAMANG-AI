import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/widgets/silvamang_button.dart';
import '../../features/measurements/data/models/camera_measurement_result.dart';

/// Manual field measurements; canopy axes never imply a calculated width.
class StructuralMeasurementFields extends StatefulWidget {
  const StructuralMeasurementFields({
    super.key,
    required this.onChanged,
    this.initial = const {},
    this.requireHeight = false,
    this.onConfirmed,
    this.onCameraUsed,
  });
  final ValueChanged<Map<String, double?>> onChanged;
  final Map<String, double?> initial;
  final bool requireHeight;
  final ValueChanged<bool>? onConfirmed;
  final VoidCallback? onCameraUsed;
  @override
  State<StructuralMeasurementFields> createState() =>
      _StructuralMeasurementFieldsState();
}

class _StructuralMeasurementFieldsState
    extends State<StructuralMeasurementFields> {
  late final values = Map<String, double?>.from(widget.initial);
  bool confirmed = false;
  late final fieldKeys = {
    for (final key in labels.keys) key: GlobalKey<FormFieldState<String>>(),
  };
  static const labels = {
    'height_m': 'Height (m)',
    'gbh_cm': 'GBH (cm) — trunk circumference',
    'canopy_1_m': 'Canopy 1 (m)',
    'canopy_2_m': 'Canopy 2 (m)',
  };
  late final controllers = {
    for (final key in labels.keys)
      key: TextEditingController(text: values[key]?.toString() ?? ''),
  };

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> measureCanopy(String key) async {
    final result = await context.pushNamed<CameraMeasurementResult>(
      RouteNames.cameraPointingMeasurement,
      queryParameters: {
        'type': key == 'height_m' ? 'tree_height' : 'canopy_width',
        'result_only': 'true',
        if (key != 'height_m') 'axis': key == 'canopy_1_m' ? '1' : '2',
      },
    );
    if (!mounted ||
        result == null ||
        !result.qualityAccepted ||
        result.measurementType !=
            (key == 'height_m' ? 'tree_height' : 'canopy_width') ||
        !result.estimatedValueM.isFinite ||
        result.estimatedValueM < .01 ||
        result.estimatedValueM > 100000) {
      return;
    }
    final value = double.parse(result.estimatedValueM.toStringAsFixed(2));
    setState(() {
      confirmed = false;
      values[key] = value;
      controllers[key]!.text = value.toString();
    });
    widget.onChanged(Map.from(values));
    widget.onConfirmed?.call(false);
    widget.onCameraUsed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final gbh = values['gbh_cm'];
    final dbh = gbh != null ? (gbh / math.pi * 100).round() / 100 : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Structural Measurements (optional)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const Text(
          'Measurements are optional. Enter any values you have, or leave them blank and save. GBH is recorded in centimeters.',
        ),
        for (final entry in labels.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextFormField(
              key: fieldKeys[entry.key],
              controller: controllers[entry.key],
              decoration: InputDecoration(labelText: entry.value),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (text) {
                if (text == null || text.trim().isEmpty) {
                  return entry.key == 'height_m' && widget.requireHeight
                      ? 'Enter height or measure it with the camera.'
                      : null;
                }
                final n = double.tryParse(text);
                return n == null || !n.isFinite || n < .01 || n > 100000
                    ? 'Enter a value from 0.01 to 100000.'
                    : null;
              },
              onChanged: (text) {
                final n = double.tryParse(text);
                setState(
                  () => values[entry.key] =
                      n != null && n.isFinite && n >= .01 && n <= 100000
                      ? n
                      : null,
                );
                setState(() => confirmed = false);
                widget.onConfirmed?.call(false);
                widget.onChanged(Map.from(values));
              },
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final key in ['height_m', 'canopy_1_m', 'canopy_2_m'])
              OutlinedButton.icon(
                onPressed: () => measureCanopy(key),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text('Measure ${labels[key]}'),
              ),
          ],
        ),
        const Text(
          'Measure the first canopy dimension, then repeat for the second dimension. You can also enter both manually.',
        ),
        if (gbh != null) Text('GBH: ${(gbh / 100).toStringAsFixed(4)} m'),
        if (dbh != null) ...[
          Text(
            'DBH: ${dbh.toStringAsFixed(2)} cm / ${(dbh / 100).toStringAsFixed(4)} m',
          ),
          Text(
            'Basal Area: ${(math.pi * math.pow(dbh / 200, 2)).toStringAsFixed(6)} m²',
          ),
        ],
        const SizedBox(height: 16),
        SilvamangButton(
          text: confirmed ? 'Measurements confirmed' : 'Confirm Measurements',
          icon: Icons.check_rounded,
          onPressed: () {
            final valid = fieldKeys.values
                .map((key) => key.currentState!.validate())
                .toList()
                .every((valid) => valid);
            if (!valid) return;
            FocusScope.of(context).unfocus();
            setState(() => confirmed = true);
            widget.onConfirmed?.call(true);
          },
        ),
      ],
    );
  }
}
