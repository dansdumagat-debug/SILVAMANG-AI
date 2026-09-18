<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Transect;
use App\Models\User;
use App\Services\VegetationWorkbookExportService;
use App\Support\ApiAccess;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\StreamedResponse;

class TransectController extends Controller
{
    public function index(Request $request): View
    {
        $canViewAll = ApiAccess::canViewAllRecords($request->user());
        $query = $this->filteredQuery($request)
            ->with([
                'user:id,name,email',
                'points',
                'observations.species',
                'observations.measurement',
                'observations.locationValidation',
            ])
            ->withCount(['points', 'observations'])
            ->orderByRaw('COALESCE(recorded_at, created_at) desc');
        $transects = $query->get();

        return view('admin.transects.index', [
            'canViewAll' => $canViewAll,
            'transects' => $transects,
            'mapTransects' => $transects->map(fn (Transect $transect) => $this->mapPayload($transect)),
            'totalDistanceM' => round((float) $transects->sum('total_distance_m'), 2),
            'totalObservations' => $transects->sum('observations_count'),
            'completedCount' => $transects->where('status', 'completed')->count(),
            'userOptions' => $canViewAll
                ? User::query()->orderBy('name')->get(['id', 'name', 'email'])
                : collect(),
        ]);
    }

    public function show(Request $request, Transect $transect): View
    {
        $this->abortUnlessCanAccess($transect, $request->user());
        $transect->load([
            'user:id,name,email',
            'points',
            'observations.species',
            'observations.measurement',
            'observations.locationValidation',
        ]);

        return view('admin.transects.show', [
            'transect' => $transect,
            'mapTransect' => $this->mapPayload($transect),
            'canViewAll' => ApiAccess::canViewAllRecords($request->user()),
            'speciesDistribution' => $transect->observations
                ->groupBy(fn ($record) => $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Unidentified')
                ->map(fn ($records, $name) => ['species' => $name, 'count' => $records->count()])
                ->sortByDesc('count')
                ->values(),
        ]);
    }

    public function export(Request $request): StreamedResponse
    {
        $transects = $this->filteredQuery($request)
            ->with(['user:id,name,email', 'observations.species'])
            ->withCount(['points', 'observations'])
            ->orderByRaw('COALESCE(recorded_at, created_at) desc')
            ->get();

        return response()->streamDownload(function () use ($transects) {
            $output = fopen('php://output', 'w');
            fwrite($output, "\xEF\xBB\xBF");
            fputcsv($output, [
                'Transect ID',
                'Name',
                'Researcher',
                'Location',
                'Date Recorded',
                'Mode',
                'Status',
                'Distance (m)',
                'Direction (degrees)',
                'Start Latitude',
                'Start Longitude',
                'End Latitude',
                'End Longitude',
                'GPS Points',
                'Observations',
                'Species Recorded',
            ]);

            foreach ($transects as $transect) {
                $species = $transect->observations
                    ->map(fn ($record) => $record->top_scientific_name ?? $record->species?->scientific_name)
                    ->filter()
                    ->unique()
                    ->implode('; ');

                fputcsv($output, [
                    $transect->transect_code,
                    $transect->transect_name,
                    $transect->user?->name,
                    $transect->location_name,
                    ($transect->recorded_at ?? $transect->created_at)?->toIso8601String(),
                    $transect->mode,
                    $transect->status,
                    $transect->total_distance_m,
                    $transect->bearing_degrees,
                    $transect->start_latitude,
                    $transect->start_longitude,
                    $transect->end_latitude,
                    $transect->end_longitude,
                    $transect->points_count,
                    $transect->observations_count,
                    $species,
                ]);
            }

            fclose($output);
        }, 'silvamang-transects-'.now()->format('Y-m-d').'.csv', [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    public function exportExcel(Request $request, VegetationWorkbookExportService $exporter): BinaryFileResponse
    {
        $validated = $request->validate([
            'plot_area_m2' => ['nullable', 'numeric', 'gt:0', 'max:1000000'],
        ]);
        $transects = $this->filteredQuery($request)
            ->with([
                'user:id,name,email',
                'observations.user:id,name,email',
                'observations.species',
                'observations.measurement',
            ])
            ->orderByRaw('COALESCE(recorded_at, created_at) desc')
            ->get();

        $path = $exporter->create(
            $transects,
            isset($validated['plot_area_m2']) ? (float) $validated['plot_area_m2'] : null
        );

        return response()->download(
            $path,
            'silvamang-vegetation-'.now()->format('Y-m-d').'.xlsx',
            ['Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
        )->deleteFileAfterSend(true);
    }

    private function filteredQuery(Request $request): Builder
    {
        $query = Transect::query();
        if (! ApiAccess::canViewAllRecords($request->user())) {
            $query->where('user_id', $request->user()->id);
        }

        return $query
            ->when($request->filled('transect_id'), fn (Builder $builder) => $builder->whereKey($request->query('transect_id')))
            ->when($request->filled('search'), function (Builder $builder) use ($request) {
                $search = trim((string) $request->query('search'));
                $builder->where(function (Builder $nested) use ($search) {
                    $nested->where('transect_code', 'like', "%{$search}%")
                        ->orWhere('transect_name', 'like', "%{$search}%")
                        ->orWhere('location_name', 'like', "%{$search}%");
                });
            })
            ->when($request->filled('mode'), fn (Builder $builder) => $builder->where('mode', $request->query('mode')))
            ->when($request->filled('status'), fn (Builder $builder) => $builder->where('status', $request->query('status')))
            ->when(
                ApiAccess::canViewAllRecords($request->user()) && $request->filled('user_id'),
                fn (Builder $builder) => $builder->where('user_id', $request->query('user_id'))
            )
            ->when($request->filled('date_from'), fn (Builder $builder) => $builder->whereDate('recorded_at', '>=', $request->query('date_from')))
            ->when($request->filled('date_to'), fn (Builder $builder) => $builder->whereDate('recorded_at', '<=', $request->query('date_to')));
    }

    private function abortUnlessCanAccess(Transect $transect, ?User $user): void
    {
        abort_unless(
            ApiAccess::canViewAllRecords($user) || $transect->user_id === $user?->id,
            404
        );
    }

    private function mapPayload(Transect $transect): array
    {
        preg_match('/\b(?:transect|t)\s*[-#]?\s*(\d+)\b/i', $transect->transect_name ?? '', $namedNumber);
        preg_match('/-(\d+)$/', $transect->transect_code ?? '', $codeNumber);
        $transectNumber = $namedNumber[1] ?? $codeNumber[1] ?? '1';

        return [
            'id' => $transect->id,
            'code' => $transect->transect_code,
            'name' => $transect->transect_name,
            'map_label' => 'T' . (int) $transectNumber,
            'location' => $transect->location_name,
            'researcher' => $transect->user?->name,
            'mode' => $transect->mode,
            'status' => $transect->status,
            'distance_m' => (float) $transect->total_distance_m,
            'bearing_degrees' => $transect->bearing_degrees !== null ? (float) $transect->bearing_degrees : null,
            'recorded_at' => ($transect->recorded_at ?? $transect->created_at)?->format('M d, Y h:i A'),
            'detail_url' => route('admin.transects.show', $transect),
            'points' => $transect->points->map(fn ($point) => [
                'latitude' => (float) $point->latitude,
                'longitude' => (float) $point->longitude,
                'accuracy_m' => $point->accuracy_m !== null ? (float) $point->accuracy_m : null,
            ])->values(),
            'segments' => collect($transect->contributions ?? [])
                ->map(function ($contribution) {
                    $points = $contribution['points'] ?? [];
                    if (count($points) < 2) {
                        return null;
                    }
                    return [
                        ['latitude' => (float) $points[0]['latitude'], 'longitude' => (float) $points[0]['longitude']],
                        ['latitude' => (float) $points[array_key_last($points)]['latitude'], 'longitude' => (float) $points[array_key_last($points)]['longitude']],
                    ];
                })->filter()->values(),
            'observations' => $transect->observations->map(function ($record) {
                $latitude = $record->latitude ?? $record->locationValidation?->latitude;
                $longitude = $record->longitude ?? $record->locationValidation?->longitude;

                return [
                    'record_code' => $record->record_code,
                    'species' => $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Unidentified',
                    'latitude' => $latitude !== null ? (float) $latitude : null,
                    'longitude' => $longitude !== null ? (float) $longitude : null,
                ];
            })->filter(fn (array $record) => $record['latitude'] !== null && $record['longitude'] !== null)->values(),
        ];
    }
}
