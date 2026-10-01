<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AiModel;
use App\Models\Measurement;
use App\Models\Prediction;
use App\Models\ScanRecord;
use App\Models\Species;
use App\Services\AIService;
use App\Support\ApiAccess;
use App\Support\ApiId;
use App\Support\SpeciesTaxonomy;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use InvalidArgumentException;

class AIController extends Controller
{
    private const UNKNOWN_MESSAGE = 'The captured image does not appear to be a supported mangrove species.';

    private const UNCERTAIN_MESSAGE = 'The captured image could not be identified as a supported mangrove species with enough confidence.';

    private const CAPTURE_RECOMMENDATION = 'Please capture mangrove leaves, roots, bark, or flowers.';

    private const CLEAR_CAPTURE_RECOMMENDATION = 'Please retake a clear photo of mangrove leaves, roots, bark, or flowers.';

    private const NO_STRUCTURE_MESSAGE = 'No mangrove structure detected. Please capture a valid mangrove image.';

    public function health(AIService $aiService)
    {
        $health = $aiService->health();
        $this->updateModelStatuses($health);

        return response()->json([
            'message' => ($health['status'] ?? null) === 'error'
                ? 'AI service is currently unavailable.'
                : 'AI service health checked successfully.',
            'data' => $health,
        ], ($health['status'] ?? null) === 'error' ? 503 : 200);
    }

    public function classify(Request $request, AIService $aiService)
    {
        $data = $this->validatedInferenceData($request);
        $response = $this->normalizeClassificationResponse(
            $aiService->classify($this->payload($data), $this->image($request))
        );
        $storage = $this->storeClassificationResult($request, $response);

        return response()->json([
            'message' => $this->responseMessage(
                $response,
                'CNN classification completed successfully.',
                'CNN classification failed.'
            ),
            'data' => $response,
            'storage' => $storage,
        ], $this->statusCode($response));
    }

    public function detect(Request $request, AIService $aiService)
    {
        $data = $this->validatedInferenceData($request);
        $response = $this->normalizeDetectionResponse(
            $aiService->detect($this->payload($data), $this->image($request))
        );
        $storage = $this->storeVisionResult(
            request: $request,
            response: $response,
            captureMode: 'api_ai_detect',
            noteLabel: 'YOLOv8 detection result'
        );

        return response()->json([
            'message' => $this->responseMessage(
                $response,
                'YOLOv8 detection completed successfully.',
                'YOLOv8 detection failed.'
            ),
            'data' => $response,
            'storage' => $storage,
        ], $this->statusCode($response));
    }

    public function segment(Request $request, AIService $aiService)
    {
        $data = $this->validatedInferenceData($request);
        $response = $aiService->segment($this->payload($data), $this->image($request));
        $storage = $this->storeVisionResult(
            request: $request,
            response: $response,
            captureMode: 'api_ai_segment',
            noteLabel: 'YOLOv8 segmentation result'
        );

        return response()->json([
            'message' => ($response['status'] ?? null) === 'error'
                ? ($response['message'] ?? 'YOLOv8 segmentation failed.')
                : 'YOLOv8 segmentation completed successfully.',
            'data' => $response,
            'storage' => $storage,
        ], $this->statusCode($response));
    }

    public function measure(Request $request, AIService $aiService)
    {
        $data = $this->validatedInferenceData($request);
        $response = $aiService->measure($this->payload($data), $this->image($request));
        $storage = $this->storeMeasurementResult($request, $response);

        return response()->json([
            'message' => ($response['status'] ?? null) === 'error'
                ? ($response['message'] ?? 'Reference measurement failed.')
                : 'Reference measurement completed successfully.',
            'data' => $response,
            'storage' => $storage,
        ], $this->statusCode($response));
    }

    /**
     * @return array<string, mixed>
     */
    private function validatedInferenceData(Request $request): array
    {
        if ($request->filled('scan_record_id')) {
            try {
                $request->merge([
                    'scan_record_id' => ApiId::decodeOrFail($request->input('scan_record_id')),
                ]);
            } catch (InvalidArgumentException) {
                abort(400, 'Invalid scan record ID.');
            }
        }

        return $request->validate([
            'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png', 'max:10240'],
            'image_base64' => ['nullable', 'string'],
            'scan_record_id' => ['nullable', 'exists:scan_records,id'],
            'persist_result' => ['nullable', 'boolean'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'measurement_type' => ['nullable', 'string', 'in:tree_height,canopy_width,height,canopy,width'],
            'reference_height_m' => ['nullable', 'numeric', 'min:0.001'],
            'subject_distance_m' => ['nullable', 'numeric', 'min:0.001'],
            'reference_distance_m' => ['nullable', 'numeric', 'min:0.001'],
            'subject_pixel_span' => ['nullable', 'numeric', 'min:0.001'],
            'reference_pixel_span' => ['nullable', 'numeric', 'min:0.001'],
            'subject_point_a_x' => ['nullable', 'numeric', 'between:0,1'],
            'subject_point_a_y' => ['nullable', 'numeric', 'between:0,1'],
            'subject_point_b_x' => ['nullable', 'numeric', 'between:0,1'],
            'subject_point_b_y' => ['nullable', 'numeric', 'between:0,1'],
            'reference_point_a_x' => ['nullable', 'numeric', 'between:0,1'],
            'reference_point_a_y' => ['nullable', 'numeric', 'between:0,1'],
            'reference_point_b_x' => ['nullable', 'numeric', 'between:0,1'],
            'reference_point_b_y' => ['nullable', 'numeric', 'between:0,1'],
        ]);
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function payload(array $data): array
    {
        return [
            'image_base64' => $data['image_base64'] ?? null,
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
            'measurement_type' => $data['measurement_type'] ?? null,
            'reference_height_m' => $data['reference_height_m'] ?? null,
            'subject_distance_m' => $data['subject_distance_m'] ?? null,
            'reference_distance_m' => $data['reference_distance_m'] ?? null,
            'subject_pixel_span' => $data['subject_pixel_span'] ?? null,
            'reference_pixel_span' => $data['reference_pixel_span'] ?? null,
            'subject_point_a_x' => $data['subject_point_a_x'] ?? null,
            'subject_point_a_y' => $data['subject_point_a_y'] ?? null,
            'subject_point_b_x' => $data['subject_point_b_x'] ?? null,
            'subject_point_b_y' => $data['subject_point_b_y'] ?? null,
            'reference_point_a_x' => $data['reference_point_a_x'] ?? null,
            'reference_point_a_y' => $data['reference_point_a_y'] ?? null,
            'reference_point_b_x' => $data['reference_point_b_x'] ?? null,
            'reference_point_b_y' => $data['reference_point_b_y'] ?? null,
        ];
    }

    private function image(Request $request): ?UploadedFile
    {
        $image = $request->file('image');

        return $image instanceof UploadedFile ? $image : null;
    }

    /**
     * @return array<string, mixed>
     */
    private function storeClassificationResult(Request $request, array $response): array
    {
        $status = $this->responseStatus($response);

        if ($status !== 'success') {
            return [
                'stored' => false,
                'reason' => match ($status) {
                    'unknown' => 'classification_rejected_unknown',
                    'uncertain' => 'classification_rejected_low_confidence',
                    default => 'ai_response_error',
                },
            ];
        }

        $speciesName = $this->displaySpeciesName($response['species_name'] ?? '');
        $confidence = $this->nullableFloat($response['confidence'] ?? null);

        if ($speciesName === '' || $confidence === null) {
            return [
                'stored' => false,
                'reason' => 'classification_result_missing_species_or_confidence',
            ];
        }

        $species = $this->speciesForName($speciesName);
        $scanRecord = $this->scanRecordForResult($request, [
            'species_id' => $species?->id,
            'top_scientific_name' => $speciesName,
            'top_common_name' => $species?->common_name,
            'confidence' => $confidence,
            'capture_mode' => 'api_ai_classify',
            'identification_status' => 'completed',
            'validation_status' => 'pending',
            'latitude' => $request->input('latitude'),
            'longitude' => $request->input('longitude'),
            'notes' => sprintf(
                'CNN classification result. Model: %s %s. Timestamp: %s.',
                $response['model_name'] ?? 'SILVAMANG CNN Classifier',
                $response['version'] ?? '',
                now()->toDateTimeString()
            ),
            'captured_at' => now(),
        ]);

        $created = 0;
        $predictionRows = $this->classificationRows($response, $speciesName, $confidence);

        foreach ($predictionRows as $row) {
            $rowSpecies = $this->speciesForName($row['scientific_name']);
            Prediction::create([
                'scan_record_id' => $scanRecord->id,
                'species_id' => $rowSpecies?->id,
                'rank' => $row['rank'],
                'scientific_name' => $row['scientific_name'],
                'common_name' => $row['common_name'] ?: $rowSpecies?->common_name,
                'confidence' => $row['confidence'],
                'model_name' => $row['model_name'],
                'model_version' => $row['model_version'],
            ]);
            $created++;
        }

        return [
            'stored' => true,
            'scan_record_id' => ApiId::encode($scanRecord->id),
            'predictions_created' => $created,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function classificationRows(array $response, string $speciesName, float $confidence): array
    {
        $rows = [];
        foreach (($response['predictions'] ?? []) as $index => $prediction) {
            if (! is_array($prediction)) {
                continue;
            }

            $name = $this->displaySpeciesName($prediction['scientific_name'] ?? '');
            $predictionConfidence = $this->nullableFloat($prediction['confidence'] ?? null);

            if ($name === '' || $predictionConfidence === null) {
                continue;
            }

            $rows[] = [
                'rank' => (int) ($prediction['rank'] ?? ($index + 1)),
                'scientific_name' => $name,
                'common_name' => (string) ($prediction['common_name'] ?? ''),
                'confidence' => $predictionConfidence,
                'model_name' => (string) ($prediction['model_name'] ?? ($response['model_name'] ?? 'SILVAMANG CNN Classifier')),
                'model_version' => (string) ($prediction['model_version'] ?? ($response['version'] ?? '')),
            ];
        }

        if ($rows === []) {
            $rows[] = [
                'rank' => 1,
                'scientific_name' => $speciesName,
                'common_name' => '',
                'confidence' => $confidence,
                'model_name' => (string) ($response['model_name'] ?? 'SILVAMANG CNN Classifier'),
                'model_version' => (string) ($response['version'] ?? ''),
            ];
        }

        return $rows;
    }

    /**
     * @return array<string, mixed>
     */
    private function storeMeasurementResult(Request $request, array $response): array
    {
        if (($response['status'] ?? null) !== 'success') {
            return [
                'stored' => false,
                'reason' => 'ai_response_error',
            ];
        }

        $height = $this->nullableFloat($response['height_m'] ?? null);
        $canopyWidth = $this->nullableFloat($response['canopy_width_m'] ?? null);
        $confidence = $this->nullableFloat($response['confidence'] ?? null);
        $measurementMethod = (string) ($response['measurement_method'] ?? 'calibrated_reference_object');
        $modelName = (string) ($response['model_name'] ?? 'SILVAMANG Calibrated Measurement');

        if ($height === null && $canopyWidth === null) {
            return [
                'stored' => false,
                'reason' => 'measurement_result_missing_values',
            ];
        }

        $scanRecord = $this->scanRecordForResult($request, [
            'capture_mode' => 'api_ai_measure',
            'identification_status' => 'pending',
            'validation_status' => 'pending',
            'latitude' => $request->input('latitude'),
            'longitude' => $request->input('longitude'),
            'height_m' => $height,
            'canopy_width_m' => $canopyWidth,
            'notes' => sprintf(
                'AI measurement result. Method: %s. Model: %s. Timestamp: %s.',
                $measurementMethod,
                $modelName,
                now()->toDateTimeString()
            ),
            'captured_at' => now(),
        ]);

        $this->syncScanRecordMeasurement($scanRecord, $height, $canopyWidth);

        $measurementData = [
            'measurement_method' => Str::limit($measurementMethod, 50, ''),
            'confidence' => $confidence,
            'notes' => $this->measurementNotes($response, $modelName),
            'measured_at' => now(),
        ];
        if ($height !== null) {
            $measurementData['height_m'] = $height;
        }
        if ($canopyWidth !== null) {
            $measurementData['canopy_width_m'] = $canopyWidth;
        }

        $measurement = Measurement::updateOrCreate(
            ['scan_record_id' => $scanRecord->id],
            $measurementData
        );

        return [
            'stored' => true,
            'scan_record_id' => ApiId::encode($scanRecord->id),
            'measurement_id' => ApiId::encode($measurement->id),
        ];
    }

    private function syncScanRecordMeasurement(ScanRecord $scanRecord, ?float $height, ?float $canopyWidth): void
    {
        $updates = [];

        if ($height !== null) {
            $updates['height_m'] = $height;
        }

        if ($canopyWidth !== null) {
            $updates['canopy_width_m'] = $canopyWidth;
        }

        if ($updates !== []) {
            $scanRecord->forceFill($updates)->save();
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function storeVisionResult(Request $request, array $response, string $captureMode, string $noteLabel): array
    {
        $status = $this->responseStatus($response);

        if ($status !== 'success') {
            return [
                'stored' => false,
                'reason' => $status === 'no_structure'
                    ? 'no_mangrove_structure_detected'
                    : 'ai_response_error',
            ];
        }

        if ($request->has('persist_result') && ! $request->boolean('persist_result')) {
            return [
                'stored' => false,
                'reason' => 'validation_only',
            ];
        }

        if ($request->filled('scan_record_id')) {
            return [
                'stored' => false,
                'reason' => 'no_detection_or_segmentation_table_exists',
                'scan_record_id' => ApiId::encode($request->input('scan_record_id')),
            ];
        }

        $scanRecord = $this->scanRecordForResult($request, [
            'capture_mode' => $captureMode,
            'identification_status' => 'processed',
            'validation_status' => 'pending',
            'latitude' => $request->input('latitude'),
            'longitude' => $request->input('longitude'),
            'notes' => $noteLabel.'. Timestamp: '.now()->toDateTimeString().'. Result: '.json_encode($response),
            'captured_at' => now(),
        ]);

        return [
            'stored' => true,
            'scan_record_id' => ApiId::encode($scanRecord->id),
            'note' => 'Stored as a scan record note because no dedicated detection/segmentation table exists yet.',
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function scanRecordForResult(Request $request, array $attributes): ScanRecord
    {
        if ($request->filled('scan_record_id')) {
            $scanRecord = ScanRecord::find($request->input('scan_record_id'));
            if ($scanRecord instanceof ScanRecord) {
                ApiAccess::abortUnlessCanAccessScanRecord($scanRecord, Auth::user());

                return $scanRecord;
            }
        }

        return ScanRecord::create(array_merge([
            'record_code' => $this->recordCode(),
            'user_id' => Auth::id(),
        ], $attributes));
    }

    private function updateModelStatuses(array $health): void
    {
        AiModel::where('model_type', 'depth_estimation')->update(['status' => 'inactive']);
        $models = [
            'cnn' => 'classification',
            'yolov8' => 'detection',
            'segmentation' => 'segmentation',
        ];

        foreach ($models as $healthKey => $modelType) {
            $available = (bool) data_get($health, "models.{$healthKey}", false);

            AiModel::query()
                ->where('model_type', $modelType)
                ->update(['status' => $available ? 'active' : 'inactive']);
        }
    }

    private function speciesForName(string $speciesName): ?Species
    {
        $lookup = $this->speciesLookupKey($speciesName);

        return Species::query()
            ->get(['id', 'scientific_name', 'common_name'])
            ->first(fn (Species $species) => $this->speciesLookupKey($species->scientific_name) === $lookup);
    }

    private function displaySpeciesName(mixed $value): string
    {
        return SpeciesTaxonomy::canonicalName($value);
    }

    private function speciesLookupKey(mixed $value): string
    {
        return SpeciesTaxonomy::lookupKey($value);
    }

    /**
     * @param  array<string, mixed>  $response
     * @return array<string, mixed>
     */
    private function normalizeClassificationResponse(array $response): array
    {
        $status = $this->responseStatus($response);

        if ($this->isUnknownClass($status)) {
            return $this->unknownClassificationResponse($response);
        }

        if ($status === 'uncertain') {
            return $this->uncertainClassificationResponse($response);
        }

        if ($status !== 'success') {
            return $response;
        }

        $speciesName = $this->displaySpeciesName($response['species_name'] ?? '');
        $confidence = $this->nullableFloat($response['confidence'] ?? null);

        if ($this->isUnknownClass($speciesName)) {
            return $this->unknownClassificationResponse($response);
        }

        if ($speciesName === ''
            || $confidence === null
            || $confidence < 0
            || $confidence > 100
            || $confidence < $this->minimumConfidencePercentage()) {
            return $this->uncertainClassificationResponse($response);
        }

        $predictions = $response['predictions'] ?? [];
        if (! is_array($predictions)) {
            $predictions = [];
        }

        $response['predictions'] = array_values(array_filter(
            $predictions,
            fn ($prediction) => is_array($prediction)
                && ! $this->isUnknownClass($prediction['scientific_name'] ?? '')
        ));

        return $response;
    }

    /**
     * @param  array<string, mixed>  $response
     * @return array<string, mixed>
     */
    private function normalizeDetectionResponse(array $response): array
    {
        $status = $this->responseStatus($response);

        if ($status === 'no_structure') {
            return $this->noStructureResponse($response);
        }

        if ($status !== 'success'
            || ! array_key_exists('detections', $response)
            || ! is_array($response['detections'])
            || $response['detections'] !== []) {
            return $response;
        }

        return $this->noStructureResponse($response);
    }

    /**
     * @param  array<string, mixed>  $response
     * @return array<string, mixed>
     */
    private function unknownClassificationResponse(array $response): array
    {
        return array_merge($response, [
            'status' => 'unknown',
            'message' => self::UNKNOWN_MESSAGE,
            'recommendation' => self::CAPTURE_RECOMMENDATION,
            'species_name' => null,
            'predictions' => [],
        ]);
    }

    /**
     * @param  array<string, mixed>  $response
     * @return array<string, mixed>
     */
    private function uncertainClassificationResponse(array $response): array
    {
        return array_merge($response, [
            'status' => 'uncertain',
            'message' => self::UNCERTAIN_MESSAGE,
            'recommendation' => self::CLEAR_CAPTURE_RECOMMENDATION,
            'species_name' => null,
            'predictions' => [],
        ]);
    }

    /**
     * @param  array<string, mixed>  $response
     * @return array<string, mixed>
     */
    private function noStructureResponse(array $response): array
    {
        return array_merge($response, [
            'status' => 'no_structure',
            'message' => self::NO_STRUCTURE_MESSAGE,
            'detections' => [],
        ]);
    }

    private function isUnknownClass(mixed $value): bool
    {
        return in_array($this->speciesLookupKey($value), [
            'unknown',
            'non mangrove',
            'nonmangrove',
            'not mangrove',
        ], true);
    }

    private function minimumConfidencePercentage(): float
    {
        $configuredThreshold = config('services.ai_service.confidence_threshold', 0.70);
        $threshold = is_numeric($configuredThreshold)
            ? (float) $configuredThreshold
            : 0.70;

        if (! is_finite($threshold) || $threshold < 0 || $threshold > 1) {
            $threshold = 0.70;
        }

        return $threshold * 100;
    }

    /**
     * @param  array<string, mixed>  $response
     */
    private function responseStatus(array $response): string
    {
        return strtolower(trim((string) ($response['status'] ?? '')));
    }

    /**
     * @param  array<string, mixed>  $response
     */
    private function responseMessage(array $response, string $successMessage, string $errorMessage): string
    {
        $status = $this->responseStatus($response);
        $responseMessage = trim((string) ($response['message'] ?? ''));

        if ($status !== 'success' && $responseMessage !== '') {
            return $responseMessage;
        }

        return $status === 'error' ? $errorMessage : $successMessage;
    }

    private function nullableFloat(mixed $value): ?float
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (! is_numeric($value)) {
            return null;
        }

        return (float) $value;
    }

    /**
     * @param  array<string, mixed>  $response
     */
    private function measurementNotes(array $response, string $modelName): string
    {
        $parts = [
            sprintf('Model: %s.', $modelName),
            sprintf('Timestamp: %s.', now()->toDateTimeString()),
        ];

        if (! empty($response['warning'])) {
            $parts[] = 'Warning: '.(string) $response['warning'];
        }

        foreach (['reference_object', 'calibration'] as $key) {
            if (! empty($response[$key]) && is_array($response[$key])) {
                $parts[] = Str::headline($key).': '.json_encode($response[$key]);
            }
        }

        return implode(' ', $parts);
    }

    private function statusCode(array $response): int
    {
        return $this->responseStatus($response) === 'error' ? 503 : 200;
    }

    private function recordCode(): string
    {
        do {
            $code = 'AI-'.now()->format('Ymd-His').'-'.Str::upper(Str::random(5));
        } while (ScanRecord::withTrashed()->where('record_code', $code)->exists());

        return $code;
    }
}
