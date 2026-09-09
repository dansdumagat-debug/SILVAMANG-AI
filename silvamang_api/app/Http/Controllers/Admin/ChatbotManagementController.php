<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ChatbotLog;
use App\Models\MangroveKnowledge;
use App\Models\ScanRecord;
use App\Models\UnansweredQuestion;
use App\Services\AIChatbotService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\View\View;
use Throwable;

class ChatbotManagementController extends Controller
{
    public function __invoke(Request $request, AIChatbotService $assistantService): View
    {
        $hasKnowledge = Schema::hasTable('mangrove_knowledge');
        $hasLogs = Schema::hasTable('chatbot_logs');
        $hasUnansweredQuestions = Schema::hasTable('unanswered_questions');
        $sourceColumn = $hasLogs && Schema::hasColumn('chatbot_logs', 'response_source')
            ? 'response_source'
            : 'source';
        $sourceExpression = $sourceColumn === 'response_source'
            ? 'COALESCE(response_source, source)'
            : 'source';

        $testResponse = null;
        $testQuestion = trim((string) $request->query('test_question', ''));
        $scanRecord = null;

        if ($testQuestion !== '') {
            $scanRecordId = $request->integer('scan_record_id') ?: null;
            $scanRecord = $scanRecordId
                ? ScanRecord::query()
                    ->with(['species', 'measurement', 'locationValidation', 'predictions'])
                    ->find($scanRecordId)
                : null;

            $testResponse = $assistantService->ask(
                question: $testQuestion,
                scanRecord: $scanRecord,
                context: 'Admin chatbot test from management console.',
                user: $request->user()
            );

            $this->recordAdminChatbotTest($request, $testQuestion, $testResponse, $scanRecord);
        }

        return view('admin.chatbot-management.index', [
            'knowledgeCount' => $hasKnowledge ? MangroveKnowledge::count() : 0,
            'activeKnowledgeCount' => $hasKnowledge && Schema::hasColumn('mangrove_knowledge', 'status')
                ? MangroveKnowledge::where('status', 'active')->count()
                : ($hasKnowledge ? MangroveKnowledge::count() : 0),
            'inactiveKnowledgeCount' => $hasKnowledge && Schema::hasColumn('mangrove_knowledge', 'status')
                ? MangroveKnowledge::where('status', 'inactive')->count()
                : 0,
            'logCount' => $hasLogs ? ChatbotLog::count() : 0,
            'unansweredQuestionCount' => $hasUnansweredQuestions
                ? UnansweredQuestion::where('status', UnansweredQuestion::STATUS_OPEN)->count()
                : 0,
            'usageBySource' => $hasLogs
                ? ChatbotLog::query()
                    ->selectRaw("{$sourceExpression} as source, COUNT(*) as total")
                    ->groupByRaw($sourceExpression)
                    ->orderByDesc('total')
                    ->get()
                : collect(),
            'frequentlyAskedQuestions' => $hasLogs
                ? ChatbotLog::query()
                    ->selectRaw('question, COUNT(*) as total')
                    ->whereNotNull('question')
                    ->groupBy('question')
                    ->orderByDesc('total')
                    ->limit(8)
                    ->get()
                : collect(),
            'unansweredQuestions' => $hasUnansweredQuestions
                ? UnansweredQuestion::query()
                    ->where('status', UnansweredQuestion::STATUS_OPEN)
                    ->orderByDesc('frequency')
                    ->latest()
                    ->limit(8)
                    ->get()
                : collect(),
            'recentLogs' => $hasLogs
                ? ChatbotLog::query()
                    ->with(['user', 'scanRecord'])
                    ->latest()
                    ->limit(6)
                    ->get()
                : collect(),
            'recentKnowledgeItems' => $hasKnowledge
                ? MangroveKnowledge::query()
                    ->latest('updated_at')
                    ->limit(5)
                    ->get()
                : collect(),
            'scanRecordOptions' => ScanRecord::query()
                ->latest()
                ->limit(25)
                ->get(['id', 'record_code', 'top_scientific_name']),
            'exampleQuestions' => [
                'What are the common mangrove species in the Philippines?',
                'What is Rhizophora apiculata?',
                'Why are mangroves important?',
                'What are mangrove zonation areas?',
                'How do mangroves protect coastal communities?',
            ],
            'testQuestion' => $testQuestion,
            'testResponse' => $testResponse,
            'testScanRecord' => $scanRecord,
        ]);
    }

    public function resolveUnanswered(UnansweredQuestion $unansweredQuestion): RedirectResponse
    {
        $unansweredQuestion->update([
            'status' => UnansweredQuestion::STATUS_RESOLVED,
        ]);

        return redirect()
            ->route('admin.chatbot-management.index')
            ->with('success', 'Unanswered question marked as resolved.');
    }

    /**
     * @param array<string, mixed> $testResponse
     */
    private function recordAdminChatbotTest(
        Request $request,
        string $question,
        array $testResponse,
        ?ScanRecord $scanRecord
    ): void {
        if (! Schema::hasTable('chatbot_logs')) {
            return;
        }

        try {
            $payload = [
                'user_id' => $request->user()?->id,
                'scan_record_id' => $scanRecord?->id,
                'question' => $question,
                'response' => $testResponse['response'] ?? $testResponse['answer'] ?? '',
                'intent' => $testResponse['intent'] ?? null,
                'source' => $testResponse['source'] ?? 'admin_test',
            ];

            if (Schema::hasColumn('chatbot_logs', 'response_source')) {
                $payload['response_source'] = $payload['source'];
            }

            if (Schema::hasColumn('chatbot_logs', 'user_role')) {
                $payload['user_role'] = $this->roleLabel($request);
            }

            ChatbotLog::create($payload);
            $this->recordUnansweredQuestion($question, $testResponse);
        } catch (Throwable) {
            // Admin testing should stay available even when logging tables are pending migration.
        }
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

    private function roleLabel(Request $request): ?string
    {
        $roles = $request->user()?->roles?->pluck('name')->filter()->join(', ');

        return $roles !== '' ? $roles : null;
    }
}
