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
        $user = auth()->user();

        if ($this->isMobileDashboardUser($user)) {
            return $this->mobileDashboard($user);
        }

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

    private function mobileDashboard(User $user)
    {
        $recordsQuery = ScanRecord::query()->where('user_id', $user->id);

        $trendRows = (clone $recordsQuery)
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

        $latestScanRecords = (clone $recordsQuery)
            ->with(['species', 'measurement', 'locationValidation'])
            ->latest()
            ->take(6)
            ->get();

        $mapPinsQuery = (clone $recordsQuery)->where(function ($query) {
            $query
                ->where(function ($scanCoordinates) {
                    $scanCoordinates->whereNotNull('latitude')->whereNotNull('longitude');
                })
                ->orWhereHas('locationValidation', function ($validationCoordinates) {
                    $validationCoordinates->whereNotNull('latitude')->whereNotNull('longitude');
                });
        });

        $mapPins = (clone $mapPinsQuery)
            ->with(['species', 'locationValidation'])
            ->latest()
            ->take(8)
            ->get();

        $topIdentifiedSpecies = (clone $recordsQuery)
            ->leftJoin('species', 'scan_records.species_id', '=', 'species.id')
            ->selectRaw('COALESCE(species.scientific_name, scan_records.top_scientific_name, "Unknown") as name, COUNT(*) as total')
            ->groupBy('name')
            ->orderByDesc('total')
            ->limit(5)
            ->get();

        $speciesCount = (clone $recordsQuery)
            ->where(function ($query) {
                $query->whereNotNull('species_id')
                    ->orWhereNotNull('top_scientific_name');
            })
            ->get(['species_id', 'top_scientific_name'])
            ->map(fn (ScanRecord $record) => $record->species_id ? "id:{$record->species_id}" : 'name:' . strtolower((string) $record->top_scientific_name))
            ->filter()
            ->unique()
            ->count();

        return view('admin.dashboard.index', [
            'isMobileDashboard' => true,
            'mobileUser' => $user,
            'personalStats' => [
                'total_scans' => (clone $recordsQuery)->count(),
                'map_pins' => (clone $mapPinsQuery)->count(),
                'species_found' => $speciesCount,
                'measurements' => Measurement::whereHas('scanRecord', fn ($query) => $query->where('user_id', $user->id))->count(),
                'validation_matches' => (clone $recordsQuery)->where('validation_status', 'match')->count(),
                'pending_sync' => (clone $recordsQuery)->whereNull('synced_at')->whereNotNull('offline_reference')->count(),
            ],
            'latestScanRecords' => $latestScanRecords,
            'mapPins' => $mapPins,
            'scanTrend' => $scanTrend,
            'topIdentifiedSpecies' => $topIdentifiedSpecies,
        ]);
    }

    private function isMobileDashboardUser(?User $user): bool
    {
        return (bool) $user?->hasRole('mobile_user')
            && ! $user->hasAnyRole(['super_admin', 'admin', 'researcher']);
    }
}
