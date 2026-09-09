<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PythonAiService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AiMeasurementController extends Controller
{
    public function __invoke(Request $request, PythonAiService $pythonAiService)
    {
        $data = $request->validate([
            'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
            'scan_record_id' => ['nullable', 'exists:scan_records,id'],
            'reference_height_m' => ['nullable', 'numeric', 'min:0'],
            'reference_distance_m' => ['nullable', 'numeric', 'min:0'],
            'plant_part' => ['nullable', 'string', Rule::in([
                'leaves',
                'bark',
                'roots',
                'flowers',
                'canopy',
                'full_tree',
                'other',
            ])],
        ]);

        try {
            $response = $pythonAiService->measure(
                payload: [
                    'scan_record_id' => $data['scan_record_id'] ?? null,
                    'plant_part' => $data['plant_part'] ?? null,
                    'reference_height_m' => $data['reference_height_m'] ?? null,
                    'reference_distance_m' => $data['reference_distance_m'] ?? null,
                ],
                image: $request->file('image')
            );

            $response['data']['source'] = $response['data']['source'] ?? 'python_ai_service';

            return response()->json([
                'message' => 'Mock AI measurement completed successfully.',
                'data' => $response['data'] ?? $response,
            ]);
        } catch (\RuntimeException) {
            return response()->json([
                'message' => 'Mock AI measurement completed using Laravel fallback.',
                'data' => [
                    'mode' => 'mock',
                    'source' => 'laravel_fallback',
                    'height_m' => 6.8,
                    'canopy_width_m' => 4.2,
                    'dbh_cm' => null,
                    'measurement_method' => 'depth_estimation_mock',
                    'confidence' => 88.0,
                    'reference_object' => [
                        'height_m' => $data['reference_height_m'] ?? null,
                        'distance_m' => $data['reference_distance_m'] ?? null,
                    ],
                    'image_count' => $request->hasFile('image') ? 1 : 0,
                    'warning' => 'Python AI service unavailable. Laravel fallback mock measurement was used.',
                    'message' => 'Laravel fallback mock measurement generated successfully.',
                ],
            ]);
        }
    }
}
