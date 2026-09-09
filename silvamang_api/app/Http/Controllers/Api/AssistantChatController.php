<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AssistantChatRequest;
use App\Models\AssistantLog;
use App\Models\ChatbotLog;
use App\Models\ScanRecord;
use App\Models\UnansweredQuestion;
use App\Services\AIChatbotService;
use App\Support\ApiAccess;
use App\Support\ApiId;
use Illuminate\Support\Facades\Schema;
use Throwable;

class AssistantChatController extends Controller
{
    public function __invoke(AssistantChatRequest $request, AIChatbotService $assistantService)
    {
        $data = $request->validated();
        $question = $data['question'] ?? $data['message'];
        $scanRecord = null;

        if (! empty($data['scan_record_id'])) {
            $scanRecord = ScanRecord::query()
                ->with(['species', 'measurement', 'locationValidation', 'predictions'])
                ->find($data['scan_record_id']);

            ApiAccess::abortUnlessCanAccessScanRecord($scanRecord, $request->user());
        }

        $answer = $assistantService->ask(
            question: $question,
            scanRecord: $scanRecord,
            context: $data['context'] ?? null,
            history: $data['history'] ?? [],
            user: $request->user()
        );

        $assistantLog = null;

        try {
            $assistantLog = AssistantLog::create([
                'user_id' => $request->user()?->id,
                'scan_record_id' => $scanRecord?->id,
                'question' => $question,
                'response' => $answer['response'],
                'intent' => $answer['intent'],
                'source' => $answer['source'],
            ]);
        } catch (Throwable) {
            // Assistant responses should still be returned during prototype logging issues.
        }

        try {
            $chatbotLogPayload = [
                'user_id' => $request->user()?->id,
                'scan_record_id' => $scanRecord?->id,
                'question' => $question,
                'response' => $answer['response'],
                'intent' => $answer['intent'],
                'source' => $answer['source'],
            ];

            if (Schema::hasColumn('chatbot_logs', 'response_source')) {
                $chatbotLogPayload['response_source'] = $answer['source'];
            }

            if (Schema::hasColumn('chatbot_logs', 'user_role')) {
                $chatbotLogPayload['user_role'] = $this->roleLabel($request);
            }

            ChatbotLog::create($chatbotLogPayload);
        } catch (Throwable) {
            // Chatbot logging should not block the educational assistant response.
        }

        try {
            $this->recordUnansweredQuestion($question, $answer);
        } catch (Throwable) {
            // Unanswered question tracking should not block the assistant response.
        }

        return response()->json([
            'message' => 'Assistant response generated successfully.',
            'data' => [
                'id' => ApiId::encode($assistantLog?->id),
                'question' => $question,
                'answer' => $answer['answer'] ?? $answer['response'],
                'response' => $answer['response'],
                'intent' => $answer['intent'],
                'source' => $answer['source'],
                'provider' => $answer['provider'] ?? null,
                'model' => $answer['model'] ?? null,
                'reference_source' => $answer['reference_source'] ?? null,
                'related_species' => $answer['related_species'] ?? null,
                'suggested_questions' => $answer['suggested_questions'] ?? [],
                'scan_record_id' => ApiId::encode($scanRecord?->id),
                'timestamp' => $answer['timestamp'] ?? now()->toIso8601String(),
                'created_at' => $assistantLog?->created_at,
            ],
        ]);
    }

    /**
     * @param array<string, mixed> $answer
     */
    private function recordUnansweredQuestion(string $question, array $answer): void
    {
        if (! Schema::hasTable('unanswered_questions') || ! $this->isUnansweredResponse($answer)) {
            return;
        }

        $cleanQuestion = trim($question);

        if ($cleanQuestion === '') {
            return;
        }

        $unansweredQuestion = UnansweredQuestion::query()
            ->where('question', $cleanQuestion)
            ->first();

        if ($unansweredQuestion instanceof UnansweredQuestion) {
            $unansweredQuestion->frequency = max(1, (int) $unansweredQuestion->frequency) + 1;
            $unansweredQuestion->status = UnansweredQuestion::STATUS_OPEN;
            $unansweredQuestion->save();

            return;
        }

        UnansweredQuestion::create([
            'question' => $cleanQuestion,
            'frequency' => 1,
            'status' => UnansweredQuestion::STATUS_OPEN,
        ]);
    }

    /**
     * @param array<string, mixed> $answer
     */
    private function isUnansweredResponse(array $answer): bool
    {
        $intent = (string) ($answer['intent'] ?? '');
        $source = (string) ($answer['source'] ?? '');
        $response = strtolower((string) ($answer['response'] ?? $answer['answer'] ?? ''));

        return $intent === 'offline_unavailable'
            || $source === 'offline_unavailable'
            || str_contains($response, "don't have enough information")
            || str_contains($response, 'no verified information')
            || str_contains($response, 'could not find a verified exact answer');
    }

    private function roleLabel(AssistantChatRequest $request): ?string
    {
        $roles = $request->user()?->roles?->pluck('name')->filter()->join(', ');

        return $roles !== '' ? $roles : null;
    }
}
