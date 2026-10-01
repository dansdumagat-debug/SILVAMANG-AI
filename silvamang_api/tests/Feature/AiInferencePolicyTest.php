<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AiInferencePolicyTest extends TestCase
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

    public function test_unknown_class_returns_guidance_without_persisting_a_species_prediction(): void
    {
        Http::fake([
            'http://ai-service.test/ai/classify' => Http::response([
                'status' => 'success',
                'species_name' => 'unknown',
                'confidence' => 98.75,
                'predictions' => [
                    [
                        'rank' => 1,
                        'scientific_name' => 'unknown',
                        'confidence' => 98.75,
                    ],
                ],
            ]),
        ]);

        $this->postJson('/api/ai/classify')
            ->assertOk()
            ->assertJsonPath('message', 'The captured image does not appear to be a supported mangrove species.')
            ->assertJsonPath('data.status', 'unknown')
            ->assertJsonPath('data.message', 'The captured image does not appear to be a supported mangrove species.')
            ->assertJsonPath('data.recommendation', 'Please capture mangrove leaves, roots, bark, or flowers.')
            ->assertJsonPath('data.species_name', null)
            ->assertJsonCount(0, 'data.predictions')
            ->assertJsonPath('storage.stored', false)
            ->assertJsonPath('storage.reason', 'classification_rejected_unknown');

        $this->assertDatabaseCount('scan_records', 0);
        $this->assertDatabaseCount('predictions', 0);
    }

    public function test_non_mangrove_status_alias_is_normalized_to_unknown(): void
    {
        Http::fake([
            'http://ai-service.test/ai/classify' => Http::response([
                'status' => 'non_mangrove',
                'species_name' => 'Rhizophora_apiculata',
                'confidence' => 99.0,
                'predictions' => [[
                    'rank' => 1,
                    'scientific_name' => 'Rhizophora_apiculata',
                    'confidence' => 99.0,
                ]],
            ]),
        ]);

        $this->postJson('/api/ai/classify')
            ->assertOk()
            ->assertJsonPath('data.status', 'unknown')
            ->assertJsonPath('data.species_name', null)
            ->assertJsonCount(0, 'data.predictions')
            ->assertJsonPath('storage.stored', false);

        $this->assertDatabaseCount('scan_records', 0);
    }

    public function test_prediction_below_the_configured_threshold_is_uncertain_and_not_persisted(): void
    {
        Http::fake([
            'http://ai-service.test/ai/classify' => Http::response([
                'status' => 'success',
                'species_name' => 'Rhizophora_apiculata',
                'confidence' => 69.99,
                'predictions' => [
                    [
                        'rank' => 1,
                        'scientific_name' => 'Rhizophora_apiculata',
                        'confidence' => 69.99,
                    ],
                ],
            ]),
        ]);

        $this->postJson('/api/ai/classify')
            ->assertOk()
            ->assertJsonPath('data.status', 'uncertain')
            ->assertJsonPath('data.recommendation', 'Please retake a clear photo of mangrove leaves, roots, bark, or flowers.')
            ->assertJsonPath('data.species_name', null)
            ->assertJsonCount(0, 'data.predictions')
            ->assertJsonPath('storage.stored', false)
            ->assertJsonPath('storage.reason', 'classification_rejected_low_confidence');

        $this->assertDatabaseCount('scan_records', 0);
        $this->assertDatabaseCount('predictions', 0);
    }

    public function test_invalid_threshold_configuration_uses_the_safe_default(): void
    {
        config(['services.ai_service.confidence_threshold' => 'not-a-number']);

        Http::fake([
            'http://ai-service.test/ai/classify' => Http::response([
                'status' => 'success',
                'species_name' => 'Rhizophora_apiculata',
                'confidence' => 50.0,
                'predictions' => [[
                    'rank' => 1,
                    'scientific_name' => 'Rhizophora_apiculata',
                    'confidence' => 50.0,
                ]],
            ]),
        ]);

        $this->postJson('/api/ai/classify')
            ->assertOk()
            ->assertJsonPath('data.status', 'uncertain')
            ->assertJsonPath('storage.stored', false);

        $this->assertDatabaseCount('scan_records', 0);
    }

    public function test_prediction_at_the_threshold_is_persisted_without_unknown_ranked_candidates(): void
    {
        Http::fake([
            'http://ai-service.test/ai/classify' => Http::response([
                'status' => 'success',
                'species_name' => 'Rhizophora_apiculata',
                'confidence' => 70.0,
                'model_name' => 'SILVAMANG CNN Classifier',
                'version' => 'test',
                'predictions' => [
                    [
                        'rank' => 1,
                        'scientific_name' => 'Rhizophora_apiculata',
                        'confidence' => 70.0,
                    ],
                    [
                        'rank' => 2,
                        'scientific_name' => 'non_mangrove',
                        'confidence' => 20.0,
                    ],
                ],
            ]),
        ]);

        $this->postJson('/api/ai/classify')
            ->assertOk()
            ->assertJsonPath('data.status', 'success')
            ->assertJsonCount(1, 'data.predictions')
            ->assertJsonPath('data.predictions.0.scientific_name', 'Rhizophora_apiculata')
            ->assertJsonPath('storage.stored', true)
            ->assertJsonPath('storage.predictions_created', 1);

        $this->assertDatabaseCount('scan_records', 1);
        $this->assertDatabaseHas('scan_records', [
            'top_scientific_name' => 'Rhizophora apiculata',
            'confidence' => 70.0,
            'identification_status' => 'completed',
        ]);
        $this->assertDatabaseCount('predictions', 1);
        $this->assertDatabaseMissing('predictions', [
            'scientific_name' => 'non mangrove',
        ]);
    }

    public function test_empty_yolo_detections_return_no_structure_without_creating_a_scan(): void
    {
        Http::fake([
            'http://ai-service.test/ai/detect' => Http::response([
                'status' => 'success',
                'detections' => [],
            ]),
        ]);

        $this->postJson('/api/ai/detect')
            ->assertOk()
            ->assertJsonPath('message', 'No mangrove structure detected. Please capture a valid mangrove image.')
            ->assertJsonPath('data.status', 'no_structure')
            ->assertJsonPath('data.message', 'No mangrove structure detected. Please capture a valid mangrove image.')
            ->assertJsonCount(0, 'data.detections')
            ->assertJsonPath('storage.stored', false)
            ->assertJsonPath('storage.reason', 'no_mangrove_structure_detected');

        $this->assertDatabaseCount('scan_records', 0);
    }

    public function test_nonempty_yolo_detections_keep_the_existing_success_behavior(): void
    {
        Http::fake([
            'http://ai-service.test/ai/detect' => Http::response([
                'status' => 'success',
                'detections' => [
                    [
                        'class' => 'leaf',
                        'confidence' => 84.5,
                        'bbox' => [10, 20, 100, 120],
                    ],
                ],
            ]),
        ]);

        $this->postJson('/api/ai/detect')
            ->assertOk()
            ->assertJsonPath('message', 'YOLOv8 detection completed successfully.')
            ->assertJsonPath('data.status', 'success')
            ->assertJsonCount(1, 'data.detections')
            ->assertJsonPath('storage.stored', true);

        $this->assertDatabaseCount('scan_records', 1);
    }

    public function test_yolo_validation_only_does_not_create_a_scan(): void
    {
        Http::fake([
            'http://ai-service.test/ai/detect' => Http::response([
                'status' => 'success',
                'detections' => [
                    [
                        'class' => 'leaf',
                        'confidence' => 84.5,
                        'bbox' => [10, 20, 100, 120],
                    ],
                ],
            ]),
        ]);

        $this->postJson('/api/ai/detect', ['persist_result' => false])
            ->assertOk()
            ->assertJsonPath('data.status', 'success')
            ->assertJsonPath('storage.stored', false)
            ->assertJsonPath('storage.reason', 'validation_only');

        $this->assertDatabaseCount('scan_records', 0);
    }
}
