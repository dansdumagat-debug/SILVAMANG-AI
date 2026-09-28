<?php

namespace Tests\Feature;

use App\Models\ScanRecord;
use App\Services\AIChatbotService;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class OpenAIChatbotServiceTest extends TestCase
{
    public function test_openai_provider_sends_an_authenticated_chat_completion_request(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://api.openai.com/v1/chat/completions' => Http::response([
                'choices' => [
                    [
                        'message' => [
                            'role' => 'assistant',
                            'content' => '  Mangroves protect coastlines.  ',
                        ],
                    ],
                ],
            ]),
        ]);

        config([
            'services.ai_chatbot.provider' => 'openai',
            'services.ai_chatbot.openai_api_key' => 'test-openai-key',
            'services.ai_chatbot.openai_model' => 'gpt-test-model',
            'services.ai_chatbot.openai_base_url' => 'https://api.openai.com/v1/',
            'services.ai_chatbot.compatible_api_key' => null,
            'services.ai_chatbot.organization' => 'org-test',
            'services.ai_chatbot.project' => 'proj-test',
            'services.ai_chatbot.max_output_tokens' => 321,
        ]);

        $result = $this->app->make(AIChatbotService::class)->callExternalAI(
            question: 'How do mangroves protect the coast?',
            context: 'Barangay: San Roque',
            history: [
                ['role' => 'user', 'content' => 'Tell me about mangroves.'],
                ['role' => 'assistant', 'content' => 'Mangroves are coastal trees.'],
            ],
        );

        $this->assertSame([
            'answer' => 'Mangroves protect coastlines.',
            'provider' => 'openai',
            'model' => 'gpt-test-model',
        ], $result);

        Http::assertSent(function (Request $request): bool {
            $messages = $request->data()['messages'] ?? [];

            return $request->method() === 'POST'
                && $request->url() === 'https://api.openai.com/v1/chat/completions'
                && $request->hasHeader('Authorization', 'Bearer test-openai-key')
                && $request->hasHeader('Accept', 'application/json')
                && $request->hasHeader('OpenAI-Organization', 'org-test')
                && $request->hasHeader('OpenAI-Project', 'proj-test')
                && $request->data()['model'] === 'gpt-test-model'
                && $request->data()['temperature'] === 0.2
                && $request->data()['store'] === false
                && $request->data()['max_completion_tokens'] === 321
                && count($messages) === 4
                && $messages[0]['role'] === 'system'
                && str_contains($messages[0]['content'], 'domain-limited assistant for mangroves')
                && str_contains($messages[0]['content'], 'Only answer within this allowed scope.')
                && ! str_contains($messages[0]['content'], 'Barangay: San Roque')
                && $messages[1] === ['role' => 'user', 'content' => 'Tell me about mangroves.']
                && $messages[2] === ['role' => 'assistant', 'content' => 'Mangroves are coastal trees.']
                && $messages[3]['role'] === 'user'
                && str_contains($messages[3]['content'], '<silvamang_context>')
                && str_contains($messages[3]['content'], 'Barangay: San Roque')
                && str_contains($messages[3]['content'], 'How do mangroves protect the coast?');
        });
        Http::assertSentCount(1);
    }

    public function test_openai_provider_returns_null_for_an_unsuccessful_response(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://api.openai.com/v1/chat/completions' => Http::response([
                'error' => ['message' => 'Invalid authentication credentials'],
            ], 401, [
                'x-request-id' => 'request-test-401',
            ]),
        ]);

        config([
            'services.ai_chatbot.provider' => 'openai',
            'services.ai_chatbot.openai_api_key' => 'invalid-test-key',
            'services.ai_chatbot.openai_model' => 'gpt-test-model',
            'services.ai_chatbot.openai_base_url' => 'https://api.openai.com/v1',
            'services.ai_chatbot.compatible_api_key' => null,
            'services.ai_chatbot.organization' => null,
            'services.ai_chatbot.project' => null,
        ]);

        $result = $this->app->make(AIChatbotService::class)
            ->callExternalAI('Why are mangroves important?');

        $this->assertNull($result);
        Http::assertSentCount(1);
    }

    public function test_openai_provider_never_uses_a_compatible_provider_key(): void
    {
        Http::preventStrayRequests();
        Http::fake();

        config([
            'services.ai_chatbot.provider' => 'openai',
            'services.ai_chatbot.openai_api_key' => '',
            'services.ai_chatbot.openai_model' => 'gpt-test-model',
            'services.ai_chatbot.openai_base_url' => 'https://api.openai.com/v1',
            'services.ai_chatbot.compatible_api_key' => 'must-not-be-used',
            'services.ai_chatbot.compatible_model' => 'unrelated-compatible-model',
            'services.ai_chatbot.compatible_base_url' => 'https://compatible.example/v1',
        ]);

        $result = $this->app->make(AIChatbotService::class)
            ->callExternalAI('What is a mangrove?');

        $this->assertNull($result);
        Http::assertNothingSent();
    }

    public function test_precise_location_names_are_excluded_from_external_context_by_default(): void
    {
        $service = $this->app->make(AIChatbotService::class);
        $method = new \ReflectionMethod($service, 'locationNameForExternalContext');
        $record = new ScanRecord([
            'manual_barangay' => 'Private field note',
            'location_name' => 'Exact survey site',
        ]);

        config(['services.ai_chatbot.include_precise_location' => false]);
        $this->assertNull($method->invoke($service, $record));

        $record->barangay = 'San Roque';
        $this->assertSame('San Roque', $method->invoke($service, $record));

        $record->barangay = null;
        config(['services.ai_chatbot.include_precise_location' => true]);
        $this->assertSame('Private field note', $method->invoke($service, $record));
    }

    public function test_compatible_provider_keeps_credentials_and_headers_separate_from_openai(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://compatible.example/v1/chat/completions' => Http::response([
                'choices' => [
                    ['message' => ['content' => 'Compatible provider answer.']],
                ],
            ]),
        ]);

        config([
            'services.ai_chatbot.provider' => 'openrouter',
            'services.ai_chatbot.openai_api_key' => 'unused-openai-key',
            'services.ai_chatbot.compatible_api_key' => 'test-compatible-key',
            'services.ai_chatbot.compatible_model' => 'compatible-model',
            'services.ai_chatbot.compatible_base_url' => 'https://compatible.example/v1',
            'services.ai_chatbot.organization' => 'org-must-not-be-sent',
            'services.ai_chatbot.project' => 'project-must-not-be-sent',
            'services.ai_chatbot.max_output_tokens' => 250,
        ]);

        $result = $this->app->make(AIChatbotService::class)
            ->callExternalAI('What is a mangrove?');

        $this->assertSame([
            'answer' => 'Compatible provider answer.',
            'provider' => 'openai_compatible',
            'model' => 'compatible-model',
        ], $result);

        Http::assertSent(function (Request $request): bool {
            $data = $request->data();

            return $request->hasHeader('Authorization', 'Bearer test-compatible-key')
                && ! $request->hasHeader('OpenAI-Organization')
                && ! $request->hasHeader('OpenAI-Project')
                && $data['max_tokens'] === 250
                && ! array_key_exists('max_completion_tokens', $data)
                && ! array_key_exists('store', $data);
        });
        Http::assertSentCount(1);
    }
}
