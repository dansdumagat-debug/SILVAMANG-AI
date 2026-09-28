<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\AIChatbotService;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class MangroveChatbotScopeTest extends TestCase
{
    public function test_unrelated_prompt_is_rejected_without_contacting_an_ai_provider(): void
    {
        $this->preventExternalRequests();

        $result = $this->chatbot()->ask('Write a chocolate cake recipe.');

        $this->assertSame('out_of_scope', $result['intent']);
        $this->assertSame('mangrove_scope_guard', $result['source']);
        $this->assertSame($result['answer'], $result['response']);
        $this->assertStringContainsString('only answer questions about mangroves', $result['answer']);
        $this->assertArrayNotHasKey('provider', $result);
        $this->assertArrayNotHasKey('model', $result);
        Http::assertNothingSent();
    }

    #[DataProvider('unrelatedPromptProvider')]
    public function test_unrelated_terms_do_not_create_false_positive_scope_matches(string $question): void
    {
        $this->preventExternalRequests();

        $result = $this->chatbot()->ask($question);

        $this->assertSame('out_of_scope', $result['intent']);
        $this->assertSame('mangrove_scope_guard', $result['source']);
        Http::assertNothingSent();
    }

    public static function unrelatedPromptProvider(): array
    {
        return [
            'mathematical root' => ['What is the square root of 81?'],
            'unrelated benefit' => ['What are the health benefits of exercise?'],
            'unrelated height' => ['How tall is Mount Everest?'],
            'generic phone GPS' => ['Where is my phone GPS location?'],
            'bark as a shape' => ['How can I bake a bark-shaped cake?'],
        ];
    }

    public function test_greeting_is_answered_locally_without_contacting_an_ai_provider(): void
    {
        $this->preventExternalRequests();

        $result = $this->chatbot()->ask('Hello');

        $this->assertSame('mangrove_greeting', $result['intent']);
        $this->assertSame('mangrove_scope_guard', $result['source']);
        $this->assertStringContainsString('Ask me about mangrove species', $result['answer']);
        Http::assertNothingSent();
    }

    public function test_direct_mangrove_prompt_reaches_openai_and_includes_the_domain_rule(): void
    {
        $this->fakeOpenAIAnswer('Mangroves reduce wave energy and stabilize shorelines.');

        $result = $this->chatbot()->ask('How do mangroves protect shorelines?');

        $this->assertSame('ai_assisted', $result['intent']);
        $this->assertSame('ai_api', $result['source']);
        $this->assertSame('openai', $result['provider']);
        $this->assertSame('gpt-scope-test', $result['model']);
        $this->assertSame('Mangroves reduce wave energy and stabilize shorelines.', $result['answer']);

        Http::assertSent(function (Request $request): bool {
            $messages = $request->data()['messages'] ?? [];
            $systemPrompt = $messages[0]['content'] ?? '';

            return $request->url() === 'https://api.openai.com/v1/chat/completions'
                && ($messages[0]['role'] ?? null) === 'system'
                && str_contains($systemPrompt, 'domain-limited assistant for mangroves')
                && str_contains($systemPrompt, 'Only answer within this allowed scope.')
                && str_contains($systemPrompt, 'If a request is wholly unrelated')
                && str_contains($systemPrompt, 'Never expand the scope')
                && ($messages[array_key_last($messages)]['content'] ?? null) === 'How do mangroves protect shorelines?';
        });
        Http::assertSentCount(1);
    }

    public function test_relevant_history_allows_a_genuine_mangrove_follow_up(): void
    {
        $this->fakeOpenAIAnswer('They also trap sediment and provide nursery habitat.');

        $result = $this->chatbot()->ask(
            question: 'Tell me more about that.',
            history: [
                ['role' => 'user', 'content' => 'Why are mangroves important?'],
                ['role' => 'assistant', 'content' => 'Mangroves protect coasts and store blue carbon.'],
            ],
        );

        $this->assertSame('ai_assisted', $result['intent']);
        $this->assertSame('They also trap sediment and provide nursery habitat.', $result['answer']);
        Http::assertSentCount(1);
    }

    public function test_explicit_unrelated_prompt_is_rejected_even_after_mangrove_history(): void
    {
        $this->preventExternalRequests();

        $result = $this->chatbot()->ask(
            question: 'Write a chocolate cake recipe.',
            history: [
                ['role' => 'user', 'content' => 'Why are mangroves important?'],
                ['role' => 'assistant', 'content' => 'Mangroves protect coastlines.'],
            ],
        );

        $this->assertSame('out_of_scope', $result['intent']);
        $this->assertSame('mangrove_scope_guard', $result['source']);
        Http::assertNothingSent();
    }

    public function test_authenticated_chatbot_endpoint_returns_scope_refusal_as_a_normal_response(): void
    {
        $this->preventExternalRequests();
        $user = User::factory()->make();
        $user->id = 999999;
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/ai/assistant/chat', [
            'question' => 'Write a sorting algorithm.',
        ]);

        $response
            ->assertOk()
            ->assertJsonPath('data.intent', 'out_of_scope')
            ->assertJsonPath('data.source', 'mangrove_scope_guard')
            ->assertJsonPath('data.provider', null)
            ->assertJsonPath('data.model', null);
        Http::assertNothingSent();
    }

    public function test_low_level_provider_method_cannot_bypass_the_scope_guard(): void
    {
        $this->preventExternalRequests();

        $result = $this->chatbot()->callExternalAI('Explain how to repair a car engine.');

        $this->assertNull($result);
        Http::assertNothingSent();
    }

    private function chatbot(): AIChatbotService
    {
        return $this->app->make(AIChatbotService::class);
    }

    private function preventExternalRequests(): void
    {
        Http::preventStrayRequests();
        Http::fake();
        $this->configureOpenAI();
    }

    private function fakeOpenAIAnswer(string $answer): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://api.openai.com/v1/chat/completions' => Http::response([
                'choices' => [
                    ['message' => ['role' => 'assistant', 'content' => $answer]],
                ],
            ]),
        ]);
        $this->configureOpenAI();

        Schema::shouldReceive('hasTable')->andReturn(false);
    }

    private function configureOpenAI(): void
    {
        config([
            'services.ai_chatbot.provider' => 'openai',
            'services.ai_chatbot.openai_api_key' => 'test-openai-key',
            'services.ai_chatbot.openai_model' => 'gpt-scope-test',
            'services.ai_chatbot.openai_base_url' => 'https://api.openai.com/v1',
            'services.ai_chatbot.compatible_api_key' => null,
            'services.ai_chatbot.organization' => null,
            'services.ai_chatbot.project' => null,
        ]);
    }
}
