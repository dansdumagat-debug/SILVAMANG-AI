<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LegacyAiPredictionPolicyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.ai_service.url' => 'http://ai-service.test',
            'services.ai_service.confidence_threshold' => 0.70,
        ]);

        Sanctum::actingAs(User::factory()->create());
    }

    public function test_predict_route_rejects_unknown_without_exposing_it_as_a_species(): void
    {
        $this->fakePrediction('unknown', 98.75);

        $this->post('/api/ai/predict', $this->requestPayload())
            ->assertOk()
            ->assertJsonPath('message', 'The captured image does not appear to be a supported mangrove species.')
            ->assertJsonPath('data.status', 'unknown')
            ->assertJsonPath('data.message', 'The captured image does not appear to be a supported mangrove species.')
            ->assertJsonPath('data.recommendation', 'Please capture mangrove leaves, roots, bark, flowers, or canopy structures.')
            ->assertJsonPath('data.top_prediction.scientific_name', '')
            ->assertJsonPath('data.top_prediction.confidence', null)
            ->assertJsonCount(0, 'data.predictions');

        $this->assertDatabaseCount('scan_records', 0);
        $this->assertDatabaseCount('predictions', 0);
    }

    public function test_mock_predict_route_rejects_non_mangrove_alias(): void
    {
        $this->fakePrediction('non_mangrove', 99.0);

        $this->post('/api/ai/mock-predict', $this->requestPayload())
            ->assertOk()
            ->assertJsonPath('data.status', 'unknown')
            ->assertJsonPath('data.top_prediction.scientific_name', '')
            ->assertJsonCount(0, 'data.predictions');
    }

    public function test_predict_route_normalizes_non_mangrove_status_alias(): void
    {
        $this->fakePrediction('Rhizophora_apiculata', 99.0, status: 'not_mangrove');

        $this->post('/api/ai/predict', $this->requestPayload())
            ->assertOk()
            ->assertJsonPath('data.status', 'unknown')
            ->assertJsonPath('data.top_prediction.scientific_name', '')
            ->assertJsonCount(0, 'data.predictions');
    }

    public function test_both_compatibility_routes_reject_predictions_below_the_configured_threshold(): void
    {
        foreach (['/api/ai/predict', '/api/ai/mock-predict'] as $route) {
            $this->fakePrediction('Rhizophora_apiculata', 69.99);

            $this->post($route, $this->requestPayload())
                ->assertOk()
                ->assertJsonPath('message', 'The captured image could not be identified as a supported mangrove species with enough confidence.')
                ->assertJsonPath('data.status', 'uncertain')
                ->assertJsonPath('data.message', 'The captured image could not be identified as a supported mangrove species with enough confidence.')
                ->assertJsonPath('data.recommendation', 'Please retake a clear photo of mangrove leaves, roots, bark, flowers, or canopy structures.')
                ->assertJsonPath('data.top_prediction.scientific_name', '')
                ->assertJsonPath('data.top_prediction.confidence', null)
                ->assertJsonCount(0, 'data.predictions');
        }

        $this->assertDatabaseCount('scan_records', 0);
        $this->assertDatabaseCount('predictions', 0);
    }

    public function test_threshold_prediction_is_kept_but_unknown_ranked_candidates_are_removed(): void
    {
        $this->fakePrediction(
            speciesName: 'Rhizophora_apiculata',
            confidence: 70.0,
            additionalPredictions: [
                [
                    'rank' => 2,
                    'scientific_name' => 'unknown',
                    'common_name' => null,
                    'confidence' => 20.0,
                ],
            ]
        );

        $this->post('/api/ai/predict', $this->requestPayload())
            ->assertOk()
            ->assertJsonPath('data.status', 'success')
            ->assertJsonPath('data.top_prediction.scientific_name', 'Rhizophora apiculata')
            ->assertJsonPath('data.top_prediction.confidence', 70)
            ->assertJsonCount(1, 'data.predictions')
            ->assertJsonPath('data.predictions.0.scientific_name', 'Rhizophora apiculata');
    }

    /**
     * @param  array<int, array<string, mixed>>  $additionalPredictions
     */
    private function fakePrediction(
        string $speciesName,
        float $confidence,
        array $additionalPredictions = [],
        string $status = 'success'
    ): void {
        $topPrediction = [
            'rank' => 1,
            'scientific_name' => $speciesName,
            'common_name' => null,
            'confidence' => $confidence,
        ];

        Http::fake([
            'http://ai-service.test/predict' => Http::response([
                'data' => [
                    'status' => $status,
                    'mode' => 'cnn_efficientnet_b0',
                    'source' => 'python_ai_service',
                    'model' => [
                        'name' => 'SILVAMANG CNN Classifier',
                        'version' => 'test',
                        'type' => 'classification',
                    ],
                    'top_prediction' => $topPrediction,
                    'predictions' => [$topPrediction, ...$additionalPredictions],
                    'received' => [
                        'image_count' => 1,
                        'plant_parts' => ['leaves'],
                    ],
                ],
            ]),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function requestPayload(): array
    {
        return [
            'image' => UploadedFile::fake()->image('mangrove.jpg', 32, 32),
            'plant_part' => 'leaves',
        ];
    }
}
