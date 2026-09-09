class AssistantChatResponseModel {
  const AssistantChatResponseModel({
    this.id,
    required this.question,
    required this.response,
    required this.intent,
    required this.source,
    this.relatedSpecies,
    this.suggestedQuestions = const [],
    this.scanRecordId,
    this.createdAt,
  });

  final String? id;
  final String question;
  final String response;
  final String intent;
  final String source;
  final String? relatedSpecies;
  final List<String> suggestedQuestions;
  final String? scanRecordId;
  final DateTime? createdAt;

  factory AssistantChatResponseModel.fromJson(Map<String, dynamic> json) {
    return AssistantChatResponseModel(
      id: _asNullableString(json['id']),
      question: _asString(json['question']),
      response: _asString(json['answer'] ?? json['response']),
      intent: _asString(json['intent'], fallback: 'general_mangrove'),
      source: _asString(
        json['source'],
        fallback: 'laravel_rule_based_assistant',
      ),
      relatedSpecies: _asNullableString(
        json['related_species'] ?? json['relatedSpecies'],
      ),
      suggestedQuestions: _asStringList(
        json['suggested_questions'] ?? json['suggestedQuestions'],
      ),
      scanRecordId: _asNullableString(
        json['scan_record_id'] ?? json['scanRecordId'],
      ),
      createdAt: _asDate(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'response': response,
      'intent': intent,
      'source': source,
      'related_species': relatedSpecies,
      'suggested_questions': suggestedQuestions,
      'scan_record_id': scanRecordId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text;
}

DateTime? _asDate(Object? value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  if (value is String && value.trim().isNotEmpty) {
    return value
        .split('|')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  return const [];
}
