<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\MockPredictionRequest;
use App\Models\Species;
use App\Services\PythonAiService;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;

class MockAiPredictionController extends Controller
{
    public function __invoke(MockPredictionRequest $request, PythonAiService $pythonAiService)
    {
        $data = $request->validated();
        $uploadedImages = $this->uploadedImages($request);
        $plantParts = $this->plantParts($request, $data, $uploadedImages !== []);
        $debug = $this->debugData(
            imageCount: count($uploadedImages),
            plantParts: $plantParts,
            forwardedToPython: false,
            pythonStatusCode: null,
            pythonResponseMode: null,
            pythonErrorIfAny: null
        );

        if ($uploadedImages === []) {
            return response()->json([
                'message' => 'AI prediction completed using Laravel fallback.',
                'data' => $this->withDebug(
                    $this->fallbackPrediction(
                        data: $data,
                        imageCount: 0,
                        warning: 'No image was received by Laravel.'
                    ),
                    $debug
                ),
            ]);
        }

        try {
            $response = $pythonAiService->predict(
                payload: [
                    'plant_parts' => $plantParts,
                    'latitude' => $data['latitude'] ?? null,
                    'longitude' => $data['longitude'] ?? null,
                ],
                images: $uploadedImages
            );

            $prediction = $this->normalizePredictionData($response['data'] ?? $response);
            $prediction = $this->withDebug(
                $prediction,
                $this->debugData(
                    imageCount: count($uploadedImages),
                    plantParts: $plantParts,
                    forwardedToPython: true,
                    pythonStatusCode: $pythonAiService->lastStatusCode(),
                    pythonResponseMode: $pythonAiService->lastResponseMode() ?? ($prediction['mode'] ?? null),
                    pythonErrorIfAny: $pythonAiService->lastError()
                )
            );
            $message = str_starts_with((string) ($prediction['mode'] ?? ''), 'cnn_')
                ? 'AI prediction completed using Python AI service.'
                : ($response['message'] ?? 'AI prediction completed successfully.');

            return response()->json([
                'message' => $message,
                'data' => $prediction,
            ]);
        } catch (\RuntimeException) {
            return response()->json([
                'message' => 'AI prediction completed using Laravel fallback.',
                'data' => $this->withDebug(
                    $this->fallbackPrediction(
                        data: array_merge($data, ['plant_parts' => $plantParts]),
                        imageCount: count($uploadedImages),
                        warning: 'Image reached Laravel, but Python AI service failed.'
                    ),
                    $this->debugData(
                        imageCount: count($uploadedImages),
                        plantParts: $plantParts,
                        forwardedToPython: true,
                        pythonStatusCode: $pythonAiService->lastStatusCode(),
                        pythonResponseMode: $pythonAiService->lastResponseMode(),
                        pythonErrorIfAny: $pythonAiService->lastError()
                    )
                ),
            ]);
        }
    }

    private function normalizePredictionData(array $prediction): array
    {
        $prediction['mode'] = $prediction['mode'] ?? 'mock';
        $prediction['source'] = $prediction['source'] ?? 'python_ai_service';
        $prediction['model'] = $prediction['model'] ?? [
            'name' => 'SILVAMANG AI Model',
            'version' => '0.1.0',
            'type' => 'classification',
        ];
        $prediction['top_prediction'] = $prediction['top_prediction'] ?? [
            'species_id' => null,
            'scientific_name' => '',
            'common_name' => null,
            'confidence' => null,
        ];
        $prediction['predictions'] = $prediction['predictions'] ?? [];
        $prediction['explanation'] = $prediction['explanation'] ?? 'AI prediction result returned by the Python AI service.';
        $prediction['measurement'] = $prediction['measurement'] ?? [
            'height_m' => null,
            'canopy_width_m' => null,
            'dbh_cm' => null,
            'measurement_method' => 'not_estimated',
            'confidence' => null,
        ];
        $prediction['location_hint'] = $prediction['location_hint'] ?? [
            'latitude' => null,
            'longitude' => null,
            'message' => 'Location validation will be performed after saving the scan record.',
        ];
        $prediction['received'] = $prediction['received'] ?? [
            'plant_parts' => [],
            'image_count' => 0,
        ];

        return $this->withSpeciesMetadata($prediction);
    }

    private function fallbackPrediction(array $data, int $imageCount, string $warning): array
    {
        return [
            'mode' => 'mock',
            'source' => 'mock_fallback',
            'warning' => $warning,
            'model' => [
                'name' => 'SILVAMANG Mock Classifier',
                'version' => '0.1.0',
                'type' => 'classification',
            ],
            'top_prediction' => [
                'species_id' => null,
                'scientific_name' => '',
                'common_name' => null,
                'confidence' => null,
            ],
            'predictions' => [],
            'explanation' => 'No valid species prediction is available from the fallback path. Capture or select an image and use the CNN service for real identification.',
            'measurement' => [
                'height_m' => null,
                'canopy_width_m' => null,
                'dbh_cm' => null,
                'measurement_method' => 'not_estimated',
                'confidence' => null,
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

    private function withSpeciesMetadata(array $prediction): array
    {
        $speciesByName = Species::query()
            ->get(['id', 'scientific_name', 'common_name'])
            ->keyBy(fn (Species $species) => $this->speciesLookupKey($species->scientific_name));
        $modelName = (string) data_get($prediction, 'model.name', 'SILVAMANG AI Model');
        $modelVersion = (string) data_get($prediction, 'model.version', '0.1.0');

        $predictionRows = [];
        foreach (Arr::wrap($prediction['predictions'] ?? []) as $row) {
            if (! is_array($row)) {
                continue;
            }

            $row['scientific_name'] = $this->displaySpeciesName($row['scientific_name'] ?? '');
            if ($row['scientific_name'] === '') {
                continue;
            }

            $species = $speciesByName->get($this->speciesLookupKey($row['scientific_name']));
            $row['species_id'] = $row['species_id'] ?? $species?->id;
            $row['common_name'] = ($row['common_name'] ?? null) ?: $species?->common_name;
            $row['model_name'] = $row['model_name'] ?? $modelName;
            $row['model_version'] = $row['model_version'] ?? $modelVersion;
            $predictionRows[] = $row;
        }

        $prediction['predictions'] = $predictionRows;

        $topPrediction = is_array($prediction['top_prediction'] ?? null)
            ? $prediction['top_prediction']
            : [];
        $topPrediction['scientific_name'] = $this->displaySpeciesName($topPrediction['scientific_name'] ?? '');

        if ($topPrediction['scientific_name'] !== '') {
            $species = $speciesByName->get($this->speciesLookupKey($topPrediction['scientific_name']));
            $topPrediction['species_id'] = $topPrediction['species_id'] ?? $species?->id;
            $topPrediction['common_name'] = ($topPrediction['common_name'] ?? null) ?: $species?->common_name;
        } elseif ($predictionRows !== []) {
            $topPrediction = [
                'species_id' => $predictionRows[0]['species_id'] ?? null,
                'scientific_name' => $predictionRows[0]['scientific_name'],
                'common_name' => $predictionRows[0]['common_name'] ?? null,
                'confidence' => $predictionRows[0]['confidence'] ?? null,
            ];
        }

        $prediction['top_prediction'] = $topPrediction;

        return $prediction;
    }

    private function displaySpeciesName(mixed $value): string
    {
        $name = trim(str_replace('_', ' ', (string) $value));

        return preg_replace('/\s+/', ' ', $name) ?? '';
    }

    private function speciesLookupKey(mixed $value): string
    {
        return strtolower($this->displaySpeciesName($value));
    }

    /**
     * @return array<int, UploadedFile>
     */
    private function uploadedImages(MockPredictionRequest $request): array
    {
        $images = [];
        $files = $request->allFiles();
        $seen = [];
        $addFile = function ($file) use (&$images, &$seen, &$addFile): void {
            if (is_array($file)) {
                foreach ($file as $nestedFile) {
                    $addFile($nestedFile);
                }

                return;
            }

            if (! $file instanceof UploadedFile) {
                return;
            }

            $key = $file->getRealPath() . '|' . $file->getClientOriginalName();
            if (isset($seen[$key])) {
                return;
            }

            $seen[$key] = true;
            $images[] = $file;
        };

        if ($request->hasFile('image')) {
            $addFile($request->file('image'));
        }

        if ($request->hasFile('images')) {
            $addFile($request->file('images'));
        }

        foreach (['image', 'images', 'images[]'] as $field) {
            if (array_key_exists($field, $files)) {
                $addFile($files[$field]);
            }
        }

        return $images;
    }

    /**
     * @return array<int, string>
     */
    private function plantParts(MockPredictionRequest $request, array $data, bool $hasImage): array
    {
        $plantParts = $data['plant_parts'] ?? $request->input('plant_parts', []);
        $plantParts = Arr::wrap($plantParts);

        if ($request->filled('plant_part')) {
            $plantParts[] = $request->input('plant_part');
        }

        $plantParts = array_values(array_filter($plantParts, fn ($part) => is_string($part) && $part !== ''));

        return $plantParts === [] && $hasImage ? ['leaves'] : $plantParts;
    }

    private function debugData(
        int $imageCount,
        array $plantParts,
        bool $forwardedToPython,
        ?int $pythonStatusCode,
        ?string $pythonResponseMode,
        ?string $pythonErrorIfAny
    ): array {
        return [
            'laravel_received_image_count' => $imageCount,
            'laravel_received_plant_parts' => $plantParts,
            'forwarded_to_python' => $forwardedToPython,
            'python_status_code' => $pythonStatusCode,
            'python_response_mode' => $pythonResponseMode,
            'python_error_if_any' => $pythonErrorIfAny,
        ];
    }

    private function withDebug(array $prediction, array $debug): array
    {
        if (app()->environment('local') || config('app.debug')) {
            $prediction['debug'] = array_merge($prediction['debug'] ?? [], $debug);
        }

        return $prediction;
    }
}
