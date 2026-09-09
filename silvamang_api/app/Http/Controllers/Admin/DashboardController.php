<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AiModel;
use App\Models\Alert;
use App\Models\Measurement;
use App\Models\ScanRecord;
use App\Models\Species;
use App\Models\User;
use App\Services\CnnMetricsReaderService;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function __invoke(CnnMetricsReaderService $cnnMetricsReader)
    {
        $topIdentifiedSpecies = ScanRecord::query()
            ->leftJoin('species', 'scan_records.species_id', '=', 'species.id')
            ->selectRaw('COALESCE(species.scientific_name, scan_records.top_scientific_name, "Unknown") as name, COUNT(*) as total')
            ->groupBy('name')
            ->orderByDesc('total')
            ->limit(5)
            ->get();

        $trendRows = ScanRecord::query()
            ->whereDate('created_at', '>=', now()->subDays(6)->toDateString())
            ->selectRaw('DATE(created_at) as scan_date, COUNT(*) as total')
            ->groupBy('scan_date')
            ->orderBy('scan_date')
            ->get()
            ->keyBy('scan_date');

        $scanTrend = collect(range(6, 0))->map(function ($daysAgo) use ($trendRows) {
            $date = now()->subDays($daysAgo)->toDateString();

            return [
                'label' => now()->subDays($daysAgo)->format('M d'),
                'count' => (int) optional($trendRows->get($date))->total,
            ];
        });

        $validationStatuses = ['match', 'mismatch', 'likely_found', 'unknown', 'pending'];
        $validationCounts = ScanRecord::query()
            ->select('validation_status', DB::raw('COUNT(*) as total'))
            ->groupBy('validation_status')
            ->pluck('total', 'validation_status');
        $validationBreakdown = collect($validationStatuses)->map(fn ($status) => [
            'label' => $status,
            'count' => (int) ($validationCounts[$status] ?? 0),
        ]);

        $aiModelHealth = [
            'active_models' => AiModel::where('status', 'active')->count(),
            'total_models' => AiModel::count(),
            'average_accuracy' => round((float) AiModel::avg('accuracy'), 2),
            'average_f1' => round((float) AiModel::avg('f1_score'), 2),
        ];

        return view('admin.dashboard.index', [
            'totalScans' => ScanRecord::count(),
            'totalSpecies' => Species::count(),
            'activeUsers' => User::count(),
            'averageAiAccuracy' => round((float) AiModel::whereNotNull('accuracy')->avg('accuracy'), 2),
            'measurementCount' => Measurement::count(),
            'validationMatchCount' => ScanRecord::where('validation_status', 'match')->count(),
            'latestScanRecords' => ScanRecord::with('species')->latest()->take(5)->get(),
            'latestAlerts' => Alert::latest()->take(5)->get(),
            'openAlertCount' => Alert::where('status', 'open')->count(),
            'topIdentifiedSpecies' => $topIdentifiedSpecies,
            'scanTrend' => $scanTrend,
            'validationBreakdown' => $validationBreakdown,
            'aiModelHealth' => $aiModelHealth,
            'cnnMetrics' => $cnnMetricsReader->metrics(),
        ]);
    }
}
