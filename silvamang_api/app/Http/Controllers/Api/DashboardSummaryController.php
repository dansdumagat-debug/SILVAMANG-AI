<?php

namespace App\Http\Controllers\Api;

use App\Models\AiModel;
use App\Models\Alert;
use App\Models\Measurement;
use App\Models\ScanRecord;
use App\Models\Species;
use App\Http\Controllers\Controller;

class DashboardSummaryController extends Controller
{
    /**
     * Handle the incoming request.
     */
    public function __invoke()
    {
        $recentIdentifications = ScanRecord::query()
            ->latest()
            ->take(5)
            ->get([
                'record_code',
                'top_scientific_name',
                'top_common_name',
                'confidence',
                'validation_status',
                'location_name',
                'created_at',
            ])
            ->map(fn (ScanRecord $scanRecord) => [
                'record_code' => $scanRecord->record_code,
                'top_scientific_name' => $scanRecord->top_scientific_name,
                'top_common_name' => $scanRecord->top_common_name,
                'confidence' => $scanRecord->confidence !== null ? (float) $scanRecord->confidence : null,
                'validation_status' => $scanRecord->validation_status,
                'location_name' => $scanRecord->location_name,
                'created_at' => $scanRecord->created_at,
            ]);

        return response()->json([
            'message' => 'Dashboard summary retrieved successfully.',
            'data' => [
                'total_species' => Species::count(),
                'total_scans' => ScanRecord::count(),
                'completed_scans' => ScanRecord::where('identification_status', 'completed')->count(),
                'pending_scans' => ScanRecord::where('identification_status', 'pending')->count(),
                'validation_matches' => ScanRecord::where('validation_status', 'match')->count(),
                'validation_mismatches' => ScanRecord::where('validation_status', 'mismatch')->count(),
                'total_measurements' => Measurement::count(),
                'average_ai_accuracy' => round((float) AiModel::whereNotNull('accuracy')->avg('accuracy'), 2),
                'active_ai_models' => AiModel::where('status', 'active')->count(),
                'open_alerts' => Alert::where('status', 'open')->count(),
                'recent_identifications' => $recentIdentifications,
            ],
        ]);
    }
}
