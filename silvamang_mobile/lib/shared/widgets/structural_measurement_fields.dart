import 'dart:math' as math;
import 'package:flutter/material.dart';

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
    'dbh_cm': 'DBH (cm) — measured diameter (optional)',
    'canopy_1_m': 'Canopy 1 (m)',
    'canopy_2_m': 'Canopy 2 (m)',
  };
  @override
  Widget build(BuildContext context) {
    final gbh = values['gbh_cm'];
    final dbh = gbh != null
        ? (gbh / math.pi * 100).round() / 100
        : values['dbh_cm'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Structural Measurements',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const Text(
          'GBH is circumference; DBH is diameter. When GBH is entered, DBH is derived from GBH ÷ π.',
        ),
        for (final entry in labels.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextFormField(
              initialValue: values[entry.key]?.toString(),
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
