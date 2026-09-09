<?php

namespace App\Services;

use App\Models\MangroveKnowledge;
use App\Models\ScanRecord;
use App\Models\Species;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Throwable;

class AIChatbotService
{
    public function __construct(private readonly MangroveAssistantService $localAssistant)
    {
    }

    /**
     * @param array<int, array{role?: string, content?: string}> $history
     */
    public function ask(
        string $question,
        ?ScanRecord $scanRecord = null,
        ?string $context = null,
        array $history = [],
        ?User $user = null
    ): array
    {
        $cleanQuestion = trim($question);
        $knowledge = $this->searchKnowledgeBase($cleanQuestion, $scanRecord);
        $species = $this->speciesFromContext($scanRecord);
        $externalContext = $this->buildExternalContext($cleanQuestion, $context, $scanRecord, $knowledge, $user);

        $externalAnswer = $this->callExternalAI($cleanQuestion, $externalContext, $history);
        if ($externalAnswer !== null) {
            return [
                'answer' => $externalAnswer['answer'],
                'response' => $externalAnswer['answer'],
                'intent' => 'ai_assisted',
                'source' => 'ai_api',
                'provider' => $externalAnswer['provider'],
                'model' => $externalAnswer['model'],
                'reference_source' => $knowledge?->reference_source,
                'related_species' => $knowledge?->related_species ?: ($species?->scientific_name ?? $scanRecord?->top_scientific_name),
                'suggested_questions' => $this->suggestedQuestions('general_mangrove', $species?->scientific_name ?? $scanRecord?->top_scientific_name),
                'timestamp' => now()->toIso8601String(),
            ];
        }

        if ($knowledge instanceof MangroveKnowledge) {
            return [
                'answer' => $knowledge->answer,
                'response' => $knowledge->answer,
                'intent' => $knowledge->category,
                'source' => 'knowledge_base',
                'reference_source' => $knowledge->reference_source,
                'related_species' => $knowledge->related_species ?: $knowledge->species_name,
                'suggested_questions' => $this->suggestedQuestions($knowledge->category, $knowledge->species_name),
                'timestamp' => now()->toIso8601String(),
            ];
        }

        if ($species instanceof Species) {
            $answer = $this->localAssistant->answer($cleanQuestion, $scanRecord);

            return [
                'answer' => $answer['response'],
                'response' => $answer['response'],
                'intent' => $answer['intent'] ?? 'species_information',
                'source' => 'knowledge_base',
                'related_species' => $species->scientific_name,
                'suggested_questions' => $this->suggestedQuestions($answer['intent'] ?? 'species_information', $species->scientific_name),
                'timestamp' => now()->toIso8601String(),
            ];
        }

        $localAnswer = $this->localAssistant->answer($cleanQuestion, $scanRecord);

        return [
            'answer' => $localAnswer['response'],
            'response' => $localAnswer['response'],
            'intent' => $localAnswer['intent'] ?? 'general_mangrove',
            'source' => 'laravel_rule_based_assistant',
            'related_species' => $scanRecord?->top_scientific_name,
            'suggested_questions' => $this->suggestedQuestions($localAnswer['intent'] ?? 'general_mangrove', $scanRecord?->top_scientific_name),
            'timestamp' => now()->toIso8601String(),
        ];
    }

    public function searchKnowledgeBase(string $question, ?ScanRecord $scanRecord = null): ?MangroveKnowledge
    {
        if (! Schema::hasTable('mangrove_knowledge')) {
            return null;
        }

        $tokens = $this->searchTokens($question);
        if ($tokens === []) {
            return null;
        }

        $query = MangroveKnowledge::query();
        $speciesName = $scanRecord?->top_scientific_name ?? $scanRecord?->species?->scientific_name;
        $hasStatus = Schema::hasColumn('mangrove_knowledge', 'status');
        $hasRelatedSpecies = Schema::hasColumn('mangrove_knowledge', 'related_species');
        $hasReferenceSource = Schema::hasColumn('mangrove_knowledge', 'reference_source');

        if ($hasStatus) {
            $query->where('status', 'active');
        }

        if ($speciesName) {
            $query->orderByRaw('CASE WHEN species_name = ? THEN 0 ELSE 1 END', [$speciesName]);
        }

        $query->where(function ($builder) use ($tokens, $speciesName, $hasRelatedSpecies, $hasReferenceSource) {
            foreach ($tokens as $token) {
                $like = "%{$token}%";
                $builder
                    ->orWhere('question', 'like', $like)
                    ->orWhere('answer', 'like', $like)
                    ->orWhere('category', 'like', $like)
                    ->orWhere('keywords', 'like', $like)
                    ->orWhere('species_name', 'like', $like);

                if ($hasRelatedSpecies) {
                    $builder->orWhere('related_species', 'like', $like);
                }

                if ($hasReferenceSource) {
                    $builder->orWhere('reference_source', 'like', $like);
                }
            }

            if ($speciesName) {
                $builder->orWhere('species_name', 'like', "%{$speciesName}%");
                if ($hasRelatedSpecies) {
                    $builder->orWhere('related_species', 'like', "%{$speciesName}%");
                }
            }
        });

        return $query->latest()->first();
    }

    /**
     * @param array<int, array{role?: string, content?: string}> $history
     * @return array{answer: string, provider: string, model: string}|null
     */
    public function callExternalAI(string $question, ?string $context = null, array $history = []): ?array
    {
        $provider = Str::lower((string) config('services.ai_chatbot.provider', 'auto'));

        return match ($provider) {
            'gemini', 'google', 'google_gemini' => $this->callGemini($question, $context, $history),
            'ollama', 'local_ollama' => $this->callOllama($question, $context, $history),
            'openai', 'openai_compatible', 'openrouter', 'groq', 'together', 'fireworks' => $this->callOpenAICompatible($question, $context, $history),
            default => $this->callAutoProvider($question, $context, $history),
        };
    }

    /**
     * @param array<int, array{role?: string, content?: string}> $history
     * @return array{answer: string, provider: string, model: string}|null
     */
    private function callAutoProvider(string $question, ?string $context = null, array $history = []): ?array
    {
        $openAIAnswer = $this->callOpenAICompatible($question, $context, $history);
        if ($openAIAnswer !== null) {
            return $openAIAnswer;
        }

        $geminiAnswer = $this->callGemini($question, $context, $history);
        if ($geminiAnswer !== null) {
            return $geminiAnswer;
        }

        return $this->callOllama($question, $context, $history);
    }

    /**
     * @param array<int, array{role?: string, content?: string}> $history
     * @return array{answer: string, provider: string, model: string}|null
     */
    private function callOpenAICompatible(string $question, ?string $context = null, array $history = []): ?array
    {
        $apiKey = (string) config('services.ai_chatbot.api_key', '');
        $baseUrl = rtrim((string) config('services.ai_chatbot.base_url', 'https://api.openai.com/v1'), '/');
        $model = (string) config('services.ai_chatbot.model', 'gpt-4o-mini');

        if ($apiKey === '' || $model === '') {
            return null;
        }

        try {
            $response = Http::acceptJson()
                ->withToken($apiKey)
                ->timeout((int) config('services.ai_chatbot.timeout', 30))
                ->post("{$baseUrl}/chat/completions", [
                    'model' => $model,
                    'messages' => $this->chatMessages($question, $context, $history),
                    'temperature' => 0.2,
                ]);

            if (! $response->successful()) {
                return null;
            }

            $answer = data_get($response->json(), 'choices.0.message.content');

            return $this->externalResult($answer, 'openai_compatible', $model);
        } catch (Throwable) {
            return null;
        }
    }

    /**
     * @param array<int, array{role?: string, content?: string}> $history
     * @return array{answer: string, provider: string, model: string}|null
     */
    private function callGemini(string $question, ?string $context = null, array $history = []): ?array
    {
        $apiKey = (string) config('services.ai_chatbot.gemini_api_key', '');
        $baseUrl = rtrim((string) config('services.ai_chatbot.gemini_url', 'https://generativelanguage.googleapis.com/v1beta'), '/');
        $model = (string) config('services.ai_chatbot.gemini_model', 'gemini-1.5-flash');

        if ($apiKey === '' || $model === '') {
            return null;
        }

        try {
            $response = Http::acceptJson()
                ->timeout((int) config('services.ai_chatbot.timeout', 30))
                ->post("{$baseUrl}/models/{$model}:generateContent?key=" . urlencode($apiKey), [
                    'systemInstruction' => [
                        'parts' => [
                            ['text' => $this->systemPrompt($context)],
                        ],
                    ],
                    'contents' => $this->geminiMessages($question, $history),
                    'generationConfig' => [
                        'temperature' => 0.2,
                    ],
                ]);

            if (! $response->successful()) {
                return null;
            }

            $answer = data_get($response->json(), 'candidates.0.content.parts.0.text');

            return $this->externalResult($answer, 'gemini', $model);
        } catch (Throwable) {
            return null;
        }
    }

    /**
     * @param array<int, array{role?: string, content?: string}> $history
     * @return array{answer: string, provider: string, model: string}|null
     */
    private function callOllama(string $question, ?string $context = null, array $history = []): ?array
    {
        $baseUrl = rtrim((string) config('services.ai_chatbot.ollama_url', 'http://127.0.0.1:11434'), '/');
        $model = (string) config('services.ai_chatbot.ollama_model', 'llama3.2');

        if ($model === '') {
            return null;
        }

        try {
            $response = Http::acceptJson()
                ->timeout((int) config('services.ai_chatbot.timeout', 30))
                ->post("{$baseUrl}/api/chat", [
                    'model' => $model,
                    'messages' => $this->chatMessages($question, $context, $history),
                    'stream' => false,
                    'options' => [
                        'temperature' => 0.2,
                    ],
                ]);

            if (! $response->successful()) {
                return null;
            }

            $answer = data_get($response->json(), 'message.content');

            return $this->externalResult($answer, 'ollama', $model);
        } catch (Throwable) {
            return null;
        }
    }

    /**
     * @param array<int, array{role?: string, content?: string}> $history
     * @return array<int, array{role: string, content: string}>
     */
    private function chatMessages(string $question, ?string $context = null, array $history = []): array
    {
        $messages = [
            [
                'role' => 'system',
                'content' => $this->systemPrompt($context),
            ],
        ];

        foreach ($this->normalizedHistory($history) as $historyMessage) {
            $messages[] = $historyMessage;
        }

        $messages[] = [
            'role' => 'user',
            'content' => $question,
        ];

        return $messages;
    }

    private function systemPrompt(?string $context = null): string
    {
        $prompt = 'You are SILVAMANG AI Assistant. Provide accurate educational information about mangroves, biodiversity, conservation, and ecological monitoring. Use the provided SILVAMANG context when available. If information is uncertain, say verification is needed.';

        if ($context !== null && trim($context) !== '') {
            $prompt .= "\n\nField context:\n" . trim($context);
        }

        return $prompt;
    }

    /**
     * @param array<int, array{role?: string, content?: string}> $history
     * @return array<int, array{role: string, parts: array<int, array{text: string}>}>
     */
    private function geminiMessages(string $question, array $history = []): array
    {
        $contents = [];

        foreach ($this->normalizedHistory($history) as $historyMessage) {
            $contents[] = [
                'role' => $historyMessage['role'] === 'assistant' ? 'model' : 'user',
                'parts' => [
                    ['text' => $historyMessage['content']],
                ],
            ];
        }

        $contents[] = [
            'role' => 'user',
            'parts' => [
                ['text' => $question],
            ],
        ];

        return $contents;
    }

    /**
     * @return array{answer: string, provider: string, model: string}|null
     */
    private function externalResult(mixed $answer, string $provider, string $model): ?array
    {
        if (! is_string($answer) || trim($answer) === '') {
            return null;
        }

        return [
            'answer' => trim($answer),
            'provider' => $provider,
            'model' => $model,
        ];
    }

    private function buildExternalContext(
        string $question,
        ?string $context,
        ?ScanRecord $scanRecord,
        ?MangroveKnowledge $knowledge,
        ?User $user
    ): string {
        $parts = [];

        if ($context !== null && trim($context) !== '') {
            $parts[] = trim($context);
        }

        if ($scanRecord instanceof ScanRecord) {
            $parts[] = $this->scanRecordContext($scanRecord);
        }

        if ($knowledge instanceof MangroveKnowledge) {
            $parts[] = implode("\n", array_filter([
                'Relevant verified knowledge base entry:',
                "Category: {$knowledge->category}",
                "Question: {$knowledge->question}",
                "Answer: {$knowledge->answer}",
                $knowledge->species_name ? "Species: {$knowledge->species_name}" : null,
                $knowledge->related_species ? "Related species: {$knowledge->related_species}" : null,
                $knowledge->reference_source ? "Reference/source: {$knowledge->reference_source}" : null,
            ]));
        }

        $observationSummary = $this->observationSummaryForQuestion($question, $user);
        if ($observationSummary !== null) {
            $parts[] = $observationSummary;
        }

        return implode("\n\n", array_filter($parts));
    }

    private function scanRecordContext(ScanRecord $scanRecord): string
    {
        $scanRecord->loadMissing(['species', 'measurement', 'locationValidation']);

        $speciesName = $scanRecord->top_scientific_name
            ?: $scanRecord->species?->scientific_name
            ?: 'Not available';
        $commonName = $scanRecord->top_common_name
            ?: $scanRecord->species?->common_name
            ?: 'Not available';
        $height = $scanRecord->height_m ?: $scanRecord->measurement?->height_m;
        $canopyWidth = $scanRecord->canopy_width_m ?: $scanRecord->measurement?->canopy_width_m;

        return implode("\n", array_filter([
            'Selected SILVAMANG scan observation:',
            "Record code: {$scanRecord->record_code}",
            "Species: {$speciesName}",
            "Common name: {$commonName}",
            $scanRecord->confidence !== null ? "Confidence: {$scanRecord->confidence}%" : null,
            $scanRecord->barangay ? "Barangay: {$scanRecord->barangay}" : null,
            $scanRecord->manual_barangay ? "Manual barangay note: {$scanRecord->manual_barangay}" : null,
            $scanRecord->latitude !== null && $scanRecord->longitude !== null
                ? "GPS: {$scanRecord->latitude}, {$scanRecord->longitude}"
                : null,
            $height !== null ? "Estimated height: {$height} meters" : null,
            $canopyWidth !== null ? "Estimated canopy width: {$canopyWidth} meters" : null,
            $scanRecord->locationValidation?->result
                ? "Location validation: {$scanRecord->locationValidation->result}. {$scanRecord->locationValidation->message}"
                : null,
            $scanRecord->captured_at ? "Captured at: {$scanRecord->captured_at->toDateTimeString()}" : null,
        ]));
    }

    private function observationSummaryForQuestion(string $question, ?User $user): ?string
    {
        if (! Schema::hasTable('scan_records') || ! $user instanceof User) {
            return null;
        }

        $lowerQuestion = Str::lower($question);
        $wantsSummary = Str::contains($lowerQuestion, [
            'summarize',
            'summary',
            'overview',
            'report',
            'scan',
            'scans',
            'observation',
            'observations',
            'records',
        ]);

        if (! $wantsSummary) {
            return null;
        }

        $query = ScanRecord::query()->with('measurement');
        $scopeLabel = 'available authorized observations';

        if (! $user->hasAnyRole(['super_admin', 'admin', 'researcher'])) {
            $query->where('user_id', $user->id);
            $scopeLabel = 'your observations';
        }

        if (Str::contains($lowerQuestion, ['this month', 'monthly'])) {
            $start = Carbon::now()->startOfMonth();
            $end = Carbon::now()->endOfMonth();
            $scopeLabel .= ' this month';

            $query->where(function ($builder) use ($start, $end) {
                $builder
                    ->whereBetween('captured_at', [$start, $end])
                    ->orWhere(function ($nested) use ($start, $end) {
                        $nested
                            ->whereNull('captured_at')
                            ->whereBetween('created_at', [$start, $end]);
                    });
            });
        }

        $records = (clone $query)
            ->latest()
            ->limit(500)
            ->get();

        $total = (clone $query)->count();
        $speciesSummary = $records
            ->map(fn (ScanRecord $record) => $record->top_scientific_name ?: $record->species?->scientific_name)
            ->filter()
            ->countBy()
            ->sortDesc()
            ->take(5)
            ->map(fn ($count, $name) => "{$name}: {$count}")
            ->values()
            ->implode('; ');
        $locationSummary = $records
            ->map(fn (ScanRecord $record) => $record->barangay ?: $record->manual_barangay ?: $record->location_name)
            ->filter()
            ->countBy()
            ->sortDesc()
            ->take(5)
            ->map(fn ($count, $name) => "{$name}: {$count}")
            ->values()
            ->implode('; ');
        $confidenceValues = $records
            ->map(fn (ScanRecord $record) => $record->confidence !== null ? (float) $record->confidence : null)
            ->filter(fn ($value) => $value !== null);
        $heightValues = $records
            ->map(fn (ScanRecord $record) => $record->height_m ?: $record->measurement?->height_m)
            ->filter(fn ($value) => $value !== null)
            ->map(fn ($value) => (float) $value);
        $canopyValues = $records
            ->map(fn (ScanRecord $record) => $record->canopy_width_m ?: $record->measurement?->canopy_width_m)
            ->filter(fn ($value) => $value !== null)
            ->map(fn ($value) => (float) $value);

        return implode("\n", [
            "Authorized observation summary for {$scopeLabel}:",
            "Total scans: {$total}",
            'Top species: ' . ($speciesSummary !== '' ? $speciesSummary : 'Not available'),
            'Top locations: ' . ($locationSummary !== '' ? $locationSummary : 'Not available'),
            'Average confidence: ' . ($confidenceValues->isNotEmpty() ? round($confidenceValues->avg(), 2) . '%' : 'Not available'),
            'Average height: ' . ($heightValues->isNotEmpty() ? round($heightValues->avg(), 2) . ' meters' : 'Not available'),
            'Average canopy width: ' . ($canopyValues->isNotEmpty() ? round($canopyValues->avg(), 2) . ' meters' : 'Not available'),
        ]);
    }

    /**
     * @param array<int, array{role?: string, content?: string}> $history
     * @return array<int, array{role: string, content: string}>
     */
    private function normalizedHistory(array $history): array
    {
        $messages = [];

        foreach (array_slice($history, -10) as $item) {
            if (! is_array($item)) {
                continue;
            }

            $role = (string) ($item['role'] ?? '');
            $content = trim((string) ($item['content'] ?? ''));

            if (! in_array($role, ['user', 'assistant'], true) || $content === '') {
                continue;
            }

            $messages[] = [
                'role' => $role,
                'content' => Str::limit($content, 2000, ''),
            ];
        }

        return $messages;
    }

    private function speciesFromContext(?ScanRecord $scanRecord): ?Species
    {
        if (! $scanRecord instanceof ScanRecord) {
            return null;
        }

        if ($scanRecord->species instanceof Species) {
            return $scanRecord->species;
        }

        $scientificName = $scanRecord->top_scientific_name;
        if (! $scientificName) {
            return null;
        }

        return Species::query()
            ->where('scientific_name', $scientificName)
            ->first();
    }

    /**
     * @return array<int, string>
     */
    private function searchTokens(string $question): array
    {
        $question = str_replace(
            ['manggroves', 'manggrovess', 'manggrove', 'mangroove', 'mangrooves'],
            ['mangroves', 'mangroves', 'mangrove', 'mangrove', 'mangroves'],
            Str::lower($question)
        );
        $tokens = preg_split('/[^a-z0-9_]+/i', $question) ?: [];

        return collect($tokens)
            ->map(fn ($token) => trim((string) $token))
            ->filter(fn ($token) => strlen($token) >= 3)
            ->reject(fn ($token) => in_array($token, ['what', 'when', 'where', 'about', 'explain', 'please', 'does', 'this', 'that'], true))
            ->unique()
            ->take(12)
            ->values()
            ->all();
    }

    /**
     * @return array<int, string>
     */
    private function suggestedQuestions(string $intent, ?string $speciesName = null): array
    {
        $speciesPrompt = $speciesName
            ? "Tell me more about {$speciesName}."
            : 'What mangrove species grow in the Philippines?';

        return match ($intent) {
            'species_information', 'species' => [
                $speciesPrompt,
                'How can I identify this species?',
                'Where is it commonly found?',
            ],
            'ecology', 'ecological_role' => [
                'How do mangroves protect coastal areas?',
                'What is blue carbon?',
                'Why are mangrove roots important?',
            ],
            'coastal_protection', 'marine_life', 'blue_carbon' => [
                'Why are mangroves important?',
                'What animals live in mangroves?',
                'How can I protect mangroves?',
            ],
            'conservation' => [
                'How can I protect mangroves?',
                'What are threats to mangroves?',
                'Where should mangroves be planted?',
            ],
            'location', 'location_information', 'location_validation' => [
                'How does location validation work?',
                'Why is barangay not available?',
                'How accurate is phone GPS?',
            ],
            'root_types' => [
                'What are prop roots?',
                'What are pneumatophores?',
                'Which species have stilt roots?',
            ],
            'adaptations' => [
                'Why do mangroves survive in salty water?',
                'What are breathing roots?',
                'How do mangroves reproduce?',
            ],
            'reproduction' => [
                'What are propagules?',
                'How do tides move mangrove seedlings?',
                'Where should mangroves be planted?',
            ],
            'zonation', 'distribution' => [
                'What mangrove species grow in the Philippines?',
                'What species grow near open water?',
                'How does location validation work?',
            ],
            'measurement' => [
                'How should I measure tree height?',
                'Why does measurement need distance?',
                'How can I improve measurement accuracy?',
            ],
            default => [
                'Why are mangroves important?',
                'What are prop roots?',
                'How can I protect mangroves?',
            ],
        };
    }
}
