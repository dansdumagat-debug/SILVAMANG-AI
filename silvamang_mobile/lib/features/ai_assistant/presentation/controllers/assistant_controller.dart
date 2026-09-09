import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/assistant_message_model.dart';
import '../../data/repositories/assistant_repository.dart';

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
      return AssistantController(
        repository: ref.watch(assistantRepositoryProvider),
      );
    });

class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.activeScanRecordId,
  });

  final List<AssistantMessageModel> messages;
  final bool isLoading;
  final String? errorMessage;
  final String? activeScanRecordId;

  AssistantState copyWith({
    List<AssistantMessageModel>? messages,
    bool? isLoading,
    String? errorMessage,
    String? activeScanRecordId,
    bool clearError = false,
    bool clearScanRecordContext = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      activeScanRecordId: clearScanRecordContext
          ? null
          : activeScanRecordId ?? this.activeScanRecordId,
    );
  }
}

class AssistantController extends StateNotifier<AssistantState> {
  AssistantController({required this.repository})
    : super(
        const AssistantState(
          messages: [
            AssistantMessageModel(
              text:
                  "Hi! I'm Silvi, your mangrove AI assistant. I can answer general mangrove questions anytime, even without a scan. I can also explain species, identification results, measurements, and location validation.",
              isUser: false,
              source: 'local_greeting',
            ),
          ],
        ),
      );

  final AssistantRepository repository;

  void setScanRecordContext(String? scanRecordId) {
    state = state.copyWith(
      activeScanRecordId: scanRecordId,
      clearScanRecordContext: scanRecordId == null,
    );
  }

  Future<void> sendQuickPrompt(String prompt) {
    return sendMessage(prompt);
  }

  Future<void> sendMessage(String question) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty || state.isLoading) {
      return Future.value();
    }

    final history = _historyForApi(state.messages);
    final userMessage = AssistantMessageModel(
      text: cleanQuestion,
      isUser: true,
      scanRecordId: state.activeScanRecordId,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      clearError: true,
    );

    try {
      final response = await repository.sendQuestion(
        question: cleanQuestion,
        scanRecordId: state.activeScanRecordId,
        history: history,
      );

      final assistantMessage = AssistantMessageModel(
        id: response.id,
        text: response.response,
        isUser: false,
        intent: response.intent,
        source: response.source,
        suggestedQuestions: response.suggestedQuestions,
        scanRecordId: response.scanRecordId,
        createdAt: response.createdAt,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
      );
    } catch (_) {
      const message = 'Unable to get assistant response. Please try again.';
      state = state.copyWith(
        messages: [
          ...state.messages,
          AssistantMessageModel(
            text: message,
            isUser: false,
            scanRecordId: state.activeScanRecordId,
            createdAt: DateTime.now(),
            isError: true,
          ),
        ],
        isLoading: false,
        errorMessage: message,
      );
    }
  }

  void clearChat() {
    state = AssistantState(
      messages: [
        const AssistantMessageModel(
          text:
              "Hi! I'm Silvi, your mangrove AI assistant. I can answer general mangrove questions anytime, even without a scan. I can also explain species, identification results, measurements, and location validation.",
          isUser: false,
          source: 'local_greeting',
        ),
      ],
      activeScanRecordId: state.activeScanRecordId,
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  List<Map<String, String>> _historyForApi(
    List<AssistantMessageModel> messages,
  ) {
    return messages
        .where((message) => !message.isError && message.source != 'local_greeting')
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.text,
          },
        )
        .toList(growable: false)
        .reversed
        .take(10)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }
}
