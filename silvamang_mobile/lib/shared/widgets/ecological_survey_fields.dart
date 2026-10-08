import 'package:flutter/material.dart';

class EcologicalSurveyFields extends StatefulWidget {
  const EcologicalSurveyFields({
    super.key,
    this.initial = const {},
    required this.onChanged,
  });
  final Map<String, dynamic> initial;
  final ValueChanged<Map<String, dynamic>> onChanged;
  @override
  State<EcologicalSurveyFields> createState() => _EcologicalSurveyFieldsState();
}

class _EcologicalSurveyFieldsState extends State<EcologicalSurveyFields> {
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = {...widget.initial};
  }

  void update(String key, dynamic value) {
    values[key] = value;
    widget.onChanged(Map.of(values));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Survey Details',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: ['Inside', 'Outside'].contains(values['survey_location'])
            ? values['survey_location'] as String
            : null,
        decoration: const InputDecoration(
          labelText: 'Survey location (optional)',
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Not recorded')),
          ...[
            'Inside',
            'Outside',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))),
        ],
        onChanged: (v) => update('survey_location', v == '' ? null : v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: values['ecological_category'] as String?,
        decoration: const InputDecoration(labelText: 'Category (optional)'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Not recorded')),
          ...[
            'Tree',
            'Sapling',
            'Seedling',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))),
        ],
        onChanged: (v) => update('ecological_category', v == '' ? null : v),
      ),
      const SizedBox(height: 12),
      TextFormField(
        initialValue: values['count_mg']?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Count-MG',
          helperText: 'Number of mangroves. Leave blank for one individual.',
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          final n = int.tryParse(v.trim());
          return n == null || n < 1 || n > 1000000
              ? 'Enter a whole number from 1 to 1000000.'
              : null;
        },
        onChanged: (v) => update('count_mg', int.tryParse(v.trim())),
      ),
      const SizedBox(height: 16),
    ],
  );
}
