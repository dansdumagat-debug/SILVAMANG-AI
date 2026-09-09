class AssistantMessageModel {
  const AssistantMessageModel({
    this.id,
    required this.text,
    required this.isUser,
    this.intent,
    this.source,
    this.suggestedQuestions = const [],
    this.scanRecordId,
    this.createdAt,
    this.isError = false,
  });

  final String? id;
  final String text;
  final bool isUser;
  final String? intent;
  final String? source;
  final List<String> suggestedQuestions;
  final String? scanRecordId;
  final DateTime? createdAt;
  final bool isError;

  AssistantMessageModel copyWith({
    String? id,
    String? text,
    bool? isUser,
    String? intent,
    String? source,
    List<String>? suggestedQuestions,
    String? scanRecordId,
    DateTime? createdAt,
    bool? isError,
  }) {
    return AssistantMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      intent: intent ?? this.intent,
      source: source ?? this.source,
      suggestedQuestions: suggestedQuestions ?? this.suggestedQuestions,
      scanRecordId: scanRecordId ?? this.scanRecordId,
      createdAt: createdAt ?? this.createdAt,
      isError: isError ?? this.isError,
    );
  }
}
