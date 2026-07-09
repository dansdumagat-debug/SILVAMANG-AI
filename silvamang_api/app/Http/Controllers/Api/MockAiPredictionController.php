<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\MockPredictionRequest;
use App\Models\Species;
use App\Services\PythonAiService;

class MockAiPredictionController extends Controller
{
    public function __invoke(MockPredictionRequest $request, PythonAiService $pythonAiService)
    {
        $data = $request->validated();
        $images = $request->file('images', []);

        try {
            $response = $pythonAiService->predict(
                payload: [
                    'plant_parts' => $data['plant_parts'] ?? [],
                    'latitude' => $data['latitude'] ?? null,
                    'longitude' => $data['longitude'] ?? null,
                ],
                images: is_array($images) ? $images : [$images]
            );

            if (isset($response['data']) && is_array($response['data'])) {
                $response['data']['source'] = 'python_ai_service';
            }

            return response()->json([
                'message' => $response['message'] ?? 'Mock AI prediction completed successfully.',
                'data' => $response['data'] ?? $response,
            ]);
        } catch (\RuntimeException) {
            return response()->json([
                'message' => 'Mock AI prediction completed successfully.',
                'data' => $this->fallbackPrediction(
                    data: $data,
                    imageCount: count($request->file('images', []))
                ),
            ]);
        }
    }

    private function fallbackPrediction(array $data, int $imageCount): array
    {
        $species = Species::query()
            ->whereIn('scientific_name', [
                'Rhizophora apiculata',
                'Rhizophora mucronata',
                'Bruguiera gymnorrhiza',
            ])
            ->get()
            ->keyBy('scientific_name');

        $predictions = [
            $this->predictionRow(
                rank: 1,
                species: $species->get('Rhizophora apiculata'),
                scientificName: 'Rhizophora apiculata',
                commonName: 'Red Mangrove',
                confidence: 92.4
            ),
            $this->predictionRow(
                rank: 2,
                species: $species->get('Rhizophora mucronata'),
                scientificName: 'Rhizophora mucronata',
                commonName: 'Red Mangrove',
                confidence: 5.1
            ),
            $this->predictionRow(
                rank: 3,
                species: $species->get('Bruguiera gymnorrhiza'),
                scientificName: 'Bruguiera gymnorrhiza',
                commonName: 'Large-leaved Orange Mangrove',
                confidence: 2.5
            ),
        ];

        return [
            'mode' => 'mock',
            'source' => 'laravel_fallback',
            'warning' => 'Python AI service unavailable. Laravel fallback mock prediction was used.',
            'model' => [
                'name' => 'SILVAMANG Mock Classifier',
                'version' => '0.1.0',
                'type' => 'classification',
            ],
            'top_prediction' => [
                'species_id' => $predictions[0]['species_id'],
                'scientific_name' => $predictions[0]['scientific_name'],
                'common_name' => $predictions[0]['common_name'],
                'confidence' => $predictions[0]['confidence'],
            ],
            'predictions' => $predictions,
            'explanation' => 'This mock result suggests Rhizophora apiculata based on the prototype classification workflow. Real AI inference will be integrated in a later phase.',
            'measurement' => [
                'height_m' => 6.8,
                'canopy_width_m' => 4.2,
                'dbh_cm' => null,
                'measurement_method' => 'depth_estimation',
                'confidence' => 88.0,
            ],
            'location_hint' => [
                'latitude' => isset($data['latitude']) ? (float) $data['latitude'] : null,
                'longitude' => isset($data['longitude']) ? (float) $data['longitude'] : null,
                'message' => 'Location validation will be performed after saving the scan record.',
            ],
            'received' => [
                'plant_parts' => $data['plant_parts'] ?? [],
                'image_count' => $imageCount,
            ],
        ];
    }

    private function predictionRow(
        int $rank,
        ?Species $species,
        string $scientificName,
        string $commonName,
        float $confidence
    ): array {
        return [
            'rank' => $rank,
            'species_id' => $species?->id,
            'scientific_name' => $species?->scientific_name ?? $scientificName,
            'common_name' => $species?->common_name ?? $commonName,
            'confidence' => $confidence,
        ];
    }
}
