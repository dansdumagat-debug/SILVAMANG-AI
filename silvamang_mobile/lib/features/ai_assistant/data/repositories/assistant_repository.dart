import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../models/assistant_chat_response_model.dart';
import '../services/offline_mangrove_knowledge_service.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(
    apiClient: ApiClient.instance,
    offlineKnowledgeService: ref.watch(offlineMangroveKnowledgeServiceProvider),
  );
});

class AssistantRepository {
  const AssistantRepository({
    required this.apiClient,
    required this.offlineKnowledgeService,
  });

  final ApiClient apiClient;
  final OfflineMangroveKnowledgeService offlineKnowledgeService;

  Future<AssistantChatResponseModel> sendQuestion({
    required String question,
    String? scanRecordId,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final body = <String, dynamic>{'message': question};
      if (scanRecordId != null) {
        body['scan_record_id'] = scanRecordId;
      }
      if (history.isNotEmpty) {
        body['history'] = history;
      }

      final response = await apiClient.post<Map<String, dynamic>>(
        '/chatbot/message',
        data: body,
      );
      final data = response.data?['data'];

      if (data is Map<String, dynamic>) {
        return AssistantChatResponseModel.fromJson(data);
      }

      return AssistantChatResponseModel.fromJson(response.data ?? {});
    } catch (_) {
      final offlineAnswer = await offlineKnowledgeService.answer(
        question: question,
      );

      return AssistantChatResponseModel(
        question: question,
        response: offlineAnswer.response,
        intent: offlineAnswer.intent,
        source: 'offline_mangrove_guide',
        relatedSpecies: offlineAnswer.relatedSpecies.isEmpty
            ? null
            : offlineAnswer.relatedSpecies.join(', '),
        suggestedQuestions: offlineAnswer.suggestedQuestions,
        scanRecordId: scanRecordId,
        createdAt: DateTime.now(),
      );
    }
  }
}
