import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../features/measurements/data/models/camera_measurement_result.dart';

/// Manual field measurements; canopy axes never imply a calculated width.
class StructuralMeasurementFields extends StatefulWidget {
  const StructuralMeasurementFields({
    super.key,
    required this.onChanged,
    this.initial = const {},
  });
  final ValueChanged<Map<String, double?>> onChanged;
  final Map<String, double?> initial;
  @override
  State<StructuralMeasurementFields> createState() =>
      _StructuralMeasurementFieldsState();
}

class _StructuralMeasurementFieldsState
    extends State<StructuralMeasurementFields> {
  late final values = Map<String, double?>.from(widget.initial);
  static const labels = {
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
        'type': 'canopy_width',
        'result_only': 'true',
        'axis': key == 'canopy_1_m' ? '1' : '2',
      },
    );
    if (!mounted ||
        result == null ||
        !result.qualityAccepted ||
        result.measurementType != 'canopy_width' ||
        !result.estimatedValueM.isFinite ||
        result.estimatedValueM < .01 ||
        result.estimatedValueM > 100000) {
      return;
    }
    final value = double.parse(result.estimatedValueM.toStringAsFixed(2));
    setState(() {
      values[key] = value;
      controllers[key]!.text = value.toString();
    });
    widget.onChanged(Map.from(values));
  }

  @override
  Widget build(BuildContext context) {
    final gbh = values['gbh_cm'];
    final dbh = gbh != null ? (gbh / math.pi * 100).round() / 100 : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Structural Measurements',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const Text(
          'Enter measured girth in centimeters. Diameter is calculated automatically from GBH.',
        ),
        for (final entry in labels.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextFormField(
              controller: controllers[entry.key],
              decoration: InputDecoration(labelText: entry.value),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (text) {
                if (text == null || text.trim().isEmpty) return null;
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
                widget.onChanged(Map.from(values));
              },
            ),
          ),
        Wrap(
          spacing: 12,
          children: [
            for (final key in ['canopy_1_m', 'canopy_2_m'])
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
        const Text(
          'Canopy Width is recorded separately; neither axis is substituted for it.',
        ),
      ],
    );
  }
}
