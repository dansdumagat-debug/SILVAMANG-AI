<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Transect;
use App\Models\User;
use App\Services\VegetationWorkbookExportService;
use App\Support\ApiAccess;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
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
        $query->orderByDesc('id');
        $totalsQuery = $this->filteredQuery($request);
        $transects = $query->paginate((int) SettingController::preferences()['records_per_page'])->withQueryString();

        return view('admin.transects.index', [
            'canViewAll' => $canViewAll,
            'transects' => $transects,
            'mapTransects' => $transects->getCollection()->map(fn (Transect $transect) => $this->mapPayload($transect)),
            'totalDistanceM' => round((float) (clone $totalsQuery)->sum('total_distance_m'), 2),
            'totalObservations' => (int) DB::query()->fromSub(
                (clone $totalsQuery)->select('id')->withCount('observations'), 'filtered_transects'
            )->sum('observations_count'),
            'completedCount' => (clone $totalsQuery)->where('status', 'completed')->count(),
            'userOptions' => $canViewAll
                ? User::query()->orderBy('name')->get(['id', 'name', 'email'])
                : collect(),
        ]);
    }

    public function updateNumber(Request $request, Transect $transect)
    {
        $this->abortUnlessCanAccess($transect, $request->user());
        $data = $request->validate(['transect_number' => ['required', 'integer', 'min:1', 'max:1000000']]);
        $transect->update($data);

        return back()->with('success', 'Field transect number saved.');
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
        $selected = collect($validated['selection'] ?? [])->unique();
        if ($request->isMethod('post')) {
            abort_unless(ApiAccess::canViewAllRecords($request->user()), 403);
            abort_if($selected->isEmpty(), 422, 'Select at least one export group.');
        }
        $transects = $this->filteredQuery($request)
            ->when($selected->isNotEmpty(), fn ($query) => $query->whereIn('id', $selected->map(fn ($key) => explode(':', $key)[0])))
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

    public function exportSelection(Request $request): View
    {
        abort_unless(ApiAccess::canViewAllRecords($request->user()), 403);
        $groups = collect();
        $transects = Transect::with(['observations.user:id,name'])->get();
        foreach ($transects as $transect) {
            foreach ($transect->observations->unique('id')->groupBy(fn ($scan) => json_encode([
                $scan->user_id, $scan->plot_no, $scan->captured_at?->format('Y-m-d'),
                $scan->location_name ?: $transect->location_name,
            ])) as $scans) {
                $first = $scans->first();
                $groups->push([
                    'recorder' => $first->user?->name ?? '', 'user' => (string) $first->user_id,
                    'transect' => $transect->transect_code ?: $transect->transect_name,
                    'transect_id' => (string) $transect->id, 'plot' => $first->plot_no ?? '',
                    'date' => $first->captured_at?->format('Y-m-d') ?? '',
                    'location' => $first->location_name ?: ($transect->location_name ?? ''),
                    'records' => $scans->map(fn ($scan) => $transect->id.':'.$scan->id)->values(),
                ]);
            }
        }

        return view('admin.transects.export-selection', ['groups' => $groups]);
    }

    public function exportExcel(Request $request, VegetationWorkbookExportService $exporter): BinaryFileResponse
    {
        $validated = $request->validate([
            'plot_area_m2' => ['nullable', 'numeric', 'gt:0', 'max:1000000'],
            'selection' => ['sometimes', 'required', 'array', 'min:1', 'max:5000'],
            'selection.*' => ['required', 'string', 'regex:/^[0-9]+:[0-9]+$/'],
        ]);
        $selected = collect($validated['selection'] ?? [])->unique();
        if ($request->isMethod('post')) {
            abort_unless(ApiAccess::canViewAllRecords($request->user()), 403);
            abort_if($selected->isEmpty(), 422, 'Select at least one export group.');
        }
        $transects = $this->filteredQuery($request)
            ->when($selected->isNotEmpty(), fn ($query) => $query->whereIn('id', $selected->map(fn ($key) => explode(':', $key)[0])))
            ->with([
                'user:id,name,email',
                'observations.user:id,name,email',
                'observations.species',
                'observations.measurement',
            ])
            ->orderByRaw('COALESCE(recorded_at, created_at) desc')
            ->get();

        if ($selected->isNotEmpty()) {
            $matched = collect();
            foreach ($transects as $transect) {
                $transect->setRelation('observations', $transect->observations->filter(function ($scan) use ($selected, $transect, $matched) {
                    $key = $transect->id.':'.$scan->id;
                    if (! $selected->contains($key)) {
                        return false;
                    }
                    $matched->push($key);

                    return true;
                })->values());
            }
            abort_unless($selected->diff($matched)->isEmpty(), 422, 'Some selected observations are no longer available. Refresh the selection.');
        }
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
            'map_label' => 'T'.(int) $transectNumber,
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
