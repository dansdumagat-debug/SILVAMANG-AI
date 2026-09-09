<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AiModel;
use App\Models\Alert;
use App\Models\AssistantLog;
use App\Models\LocationValidation;
use App\Models\Measurement;
use App\Models\ScanImage;
use App\Models\ScanRecord;
use App\Models\Species;
use App\Models\User;
use App\Services\CnnMetricsReaderService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;

class ReportController extends Controller
{
    public function index(Request $request, CnnMetricsReaderService $cnnMetricsReader)
    {
        $filters = $request->only([
            'date_from',
            'date_to',
            'species_id',
            'validation_status',
            'identification_status',
        ]);

        $scanQuery = $this->filteredScanQuery($filters);
        $filteredScanIds = (clone $scanQuery)->pluck('id');

        $totalScans = (clone $scanQuery)->count();
        $completedScans = (clone $scanQuery)->where('identification_status', 'completed')->count();
        $pendingScans = (clone $scanQuery)->where('identification_status', 'pending')->count();
        $failedScans = (clone $scanQuery)->where('identification_status', 'failed')->count();
        $averageConfidence = round((float) (clone $scanQuery)->avg('confidence'), 2);
        $totalSpecies = Species::count();
        $totalUsers = User::count();
        $totalUploadedImages = ScanImage::count();
        $totalMeasurements = Measurement::whereIn('scan_record_id', $filteredScanIds)->count();
        $totalAssistantLogs = AssistantLog::count();
        $totalAlerts = Alert::count();
        $validationMatches = (clone $scanQuery)->where('validation_status', 'match')->count();
        $validationMismatches = (clone $scanQuery)->where('validation_status', 'mismatch')->count();
        $validationLikelyFound = (clone $scanQuery)->where('validation_status', 'likely_found')->count();
        $validationUnknown = (clone $scanQuery)->where('validation_status', 'unknown')->count();

        $mostIdentifiedSpecies = (clone $scanQuery)
            ->leftJoin('species', 'scan_records.species_id', '=', 'species.id')
            ->selectRaw('COALESCE(species.scientific_name, scan_records.top_scientific_name, "Unknown") as name, COUNT(*) as total')
            ->groupBy('name')
            ->orderByDesc('total')
            ->limit(5)
            ->get();

        $scanTrendQuery = $this->filteredScanQuery($filters)
            ->selectRaw('DATE(created_at) as scan_date, COUNT(*) as total')
            ->groupBy('scan_date')
            ->orderBy('scan_date');

        if (empty($filters['date_from']) && empty($filters['date_to'])) {
            $scanTrendQuery->whereDate('created_at', '>=', now()->subDays(6)->toDateString());
        }

        $scanTrendRows = $scanTrendQuery->get()->keyBy('scan_date');
        $scanTrend = empty($filters['date_from']) && empty($filters['date_to'])
            ? collect(range(6, 0))->map(function ($daysAgo) use ($scanTrendRows) {
                $date = now()->subDays($daysAgo)->toDateString();

                return [
                    'label' => now()->subDays($daysAgo)->format('M d'),
                    'count' => (int) optional($scanTrendRows->get($date))->total,
                ];
            })
            : $scanTrendRows->map(fn ($row) => [
                'label' => date('M d', strtotime($row->scan_date)),
                'count' => (int) $row->total,
            ])->values();

        $validationStatuses = ['match', 'mismatch', 'likely_found', 'unknown', 'pending'];
        $validationCounts = (clone $scanQuery)
            ->select('validation_status', DB::raw('COUNT(*) as total'))
            ->groupBy('validation_status')
            ->pluck('total', 'validation_status');
        $validationBreakdown = collect($validationStatuses)->map(fn ($status) => [
            'label' => $status,
            'count' => (int) ($validationCounts[$status] ?? 0),
        ]);

        $measurementQuery = Measurement::whereIn('scan_record_id', $filteredScanIds);
        $measurementSummary = [
            'average_height_m' => round((float) (clone $measurementQuery)->avg('height_m'), 2),
            'average_canopy_width_m' => round((float) (clone $measurementQuery)->avg('canopy_width_m'), 2),
            'average_dbh_cm' => round((float) (clone $measurementQuery)->avg('dbh_cm'), 2),
            'total' => (clone $measurementQuery)->count(),
        ];

        $aiModelSummary = [
            'total_models' => AiModel::count(),
            'active_models' => AiModel::where('status', 'active')->count(),
            'average_accuracy' => round((float) AiModel::avg('accuracy'), 2),
            'average_precision' => round((float) AiModel::avg('precision_score'), 2),
            'average_recall' => round((float) AiModel::avg('recall_score'), 2),
            'average_f1' => round((float) AiModel::avg('f1_score'), 2),
            'average_top_k' => round((float) AiModel::avg('top_k_accuracy'), 2),
        ];

        $assistantIntentSummary = AssistantLog::query()
            ->select('intent', DB::raw('COUNT(*) as total'))
            ->groupBy('intent')
            ->orderByDesc('total')
            ->limit(6)
            ->get();

        $imageSummary = [
            'total' => $totalUploadedImages,
            'verified' => ScanImage::where('dataset_status', 'verified')->count(),
            'pending' => ScanImage::where('dataset_status', 'pending')->count(),
            'exported' => ScanImage::where('dataset_status', 'exported')->count(),
        ];

        $datasetSummary = $this->datasetSummary();

        $cnnMetrics = $cnnMetricsReader->metrics();
        $cnnClassificationReport = $cnnMetricsReader->classificationReport();
        $cnnConfusionMatrixPreview = $cnnMetricsReader->confusionMatrixPreviewPath();

        $alertStatuses = ['open', 'reviewed', 'resolved', 'dismissed'];
        $alertSeverities = ['low', 'medium', 'high', 'critical'];
        $alertStatusCounts = Alert::select('status', DB::raw('COUNT(*) as total'))->groupBy('status')->pluck('total', 'status');
        $alertSeverityCounts = Alert::select('severity', DB::raw('COUNT(*) as total'))->groupBy('severity')->pluck('total', 'severity');
        $alertSummary = [
            'statuses' => collect($alertStatuses)->mapWithKeys(fn ($status) => [$status => (int) ($alertStatusCounts[$status] ?? 0)]),
            'severities' => collect($alertSeverities)->mapWithKeys(fn ($severity) => [$severity => (int) ($alertSeverityCounts[$severity] ?? 0)]),
        ];

        return view('admin.reports.index', [
            'totalScans' => $totalScans,
            'completedScans' => $completedScans,
            'pendingScans' => $pendingScans,
            'failedScans' => $failedScans,
            'averageConfidence' => $averageConfidence,
            'totalSpecies' => $totalSpecies,
            'totalUsers' => $totalUsers,
            'totalUploadedImages' => $totalUploadedImages,
            'totalMeasurements' => $totalMeasurements,
            'totalAssistantLogs' => $totalAssistantLogs,
            'totalAlerts' => $totalAlerts,
            'validationMatches' => $validationMatches,
            'validationMismatches' => $validationMismatches,
            'validationLikelyFound' => $validationLikelyFound,
            'validationUnknown' => $validationUnknown,
            'mostIdentifiedSpecies' => $mostIdentifiedSpecies,
            'scanTrend' => $scanTrend,
            'validationBreakdown' => $validationBreakdown,
            'measurementSummary' => $measurementSummary,
            'aiModelSummary' => $aiModelSummary,
            'assistantIntentSummary' => $assistantIntentSummary,
            'imageSummary' => $imageSummary,
            'datasetSummary' => $datasetSummary,
            'cnnMetrics' => $cnnMetrics,
            'cnnClassificationReport' => $cnnClassificationReport,
            'cnnConfusionMatrixPreview' => $cnnConfusionMatrixPreview,
            'alertSummary' => $alertSummary,
            'recentRecords' => (clone $scanQuery)->with('species')->latest()->take(8)->get(),
            'recentAlerts' => Alert::latest()->take(5)->get(),
            'speciesOptions' => Species::orderBy('scientific_name')->get(['id', 'scientific_name']),
            'identificationStatuses' => ScanRecord::whereNotNull('identification_status')->distinct()->orderBy('identification_status')->pluck('identification_status'),
            'validationStatuses' => ScanRecord::whereNotNull('validation_status')->distinct()->orderBy('validation_status')->pluck('validation_status'),
        ]);
    }

    private function filteredScanQuery(array $filters): Builder
    {
        return ScanRecord::query()
            ->when($filters['date_from'] ?? null, fn ($query, $date) => $query->whereDate('created_at', '>=', $date))
            ->when($filters['date_to'] ?? null, fn ($query, $date) => $query->whereDate('created_at', '<=', $date))
            ->when($filters['species_id'] ?? null, fn ($query, $speciesId) => $query->where('species_id', $speciesId))
            ->when($filters['validation_status'] ?? null, fn ($query, $status) => $query->where('validation_status', $status))
            ->when($filters['identification_status'] ?? null, fn ($query, $status) => $query->where('identification_status', $status));
    }

    private function datasetSummary(): array
    {
        $rawPath = base_path('../dataset/raw');

        if (! File::isDirectory($rawPath)) {
            return [
                'available' => false,
                'species_count' => 0,
                'image_count' => 0,
                'note' => 'Dataset summary is available through dataset/scripts/summarize_dataset.py.',
            ];
        }

        $speciesDirectories = collect(File::directories($rawPath));
        $imageCount = collect(File::allFiles($rawPath))
            ->filter(fn ($file) => in_array(strtolower($file->getExtension()), ['jpg', 'jpeg', 'png', 'webp'], true))
            ->count();

        return [
            'available' => true,
            'species_count' => $speciesDirectories->count(),
            'image_count' => $imageCount,
            'note' => 'Dataset summary is based on files currently present in dataset/raw.',
        ];
    }
}
