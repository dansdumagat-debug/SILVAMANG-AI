<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTransectRequest;
use App\Http\Requests\UpdateTransectRequest;
use App\Http\Resources\TransectResource;
use App\Models\ScanRecord;
use App\Models\Transect;
use App\Models\User;
use App\Services\TransectGeometryService;
use App\Support\ApiAccess;
use App\Support\ApiId;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

class TransectController extends Controller
{
    public function __construct(private readonly TransectGeometryService $geometryService)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $canViewAll = ApiAccess::canViewAllRecords($user);
        $scope = $canViewAll && $request->query('scope', 'all') === 'all' ? 'all' : 'mine';

        $query = Transect::query()
            ->with($this->resourceRelations())
            ->withCount(['points', 'observations'])
            ->when($scope === 'mine', fn (Builder $builder) => $builder->where('user_id', $user->id))
            ->when($request->filled('search'), function (Builder $builder) use ($request) {
                $search = trim((string) $request->query('search'));
                $builder->where(function (Builder $nested) use ($search) {
                    $nested->where('transect_code', 'like', "%{$search}%")
                        ->orWhere('transect_name', 'like', "%{$search}%")
                        ->orWhere('location_name', 'like', "%{$search}%");
                });
            })
            ->when($request->filled('status'), fn (Builder $builder) => $builder->where('status', $request->query('status')))
            ->when($request->filled('mode'), fn (Builder $builder) => $builder->where('mode', $request->query('mode')))
            ->orderByRaw('COALESCE(recorded_at, created_at) desc');

        $transects = $query->get();

        return response()->json([
            'message' => 'Transect records retrieved successfully.',
            'scope' => $scope,
            'counts' => [
                'returned' => $transects->count(),
                'mine' => Transect::query()->where('user_id', $user->id)->count(),
                'all' => $canViewAll ? Transect::query()->count() : null,
                'pending_sync' => $transects->whereNotNull('pending_observation_references')
                    ->filter(fn (Transect $transect) => count($transect->pending_observation_references ?? []) > 0)
                    ->count(),
            ],
            'data' => TransectResource::collection($transects),
        ]);
    }

    public function store(StoreTransectRequest $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->validated();
        $offlineReference = $data['offline_reference'] ?? null;
        $existing = $offlineReference
            ? Transect::withTrashed()->where('offline_reference', $offlineReference)->first()
            : null;

        if ($existing && $existing->user_id !== $user->id) {
            abort(409, 'That offline transect reference is already in use.');
        }

        $isNew = $existing === null;
        $transect = DB::transaction(function () use ($data, $user, $existing) {
            $transect = $existing ?? new Transect();
            if ($transect->trashed()) {
                $transect->restore();
            }
            $this->persist($transect, $data, $user, true);

            return $transect;
        });

        return response()->json([
            'message' => $isNew
                ? 'Transect created successfully.'
                : 'Offline transect synchronized successfully.',
            'data' => new TransectResource($transect->load($this->resourceRelations())),
        ], $isNew ? 201 : 200);
    }

    public function show(Request $request, Transect $transect): JsonResponse
    {
        $this->abortUnlessCanAccess($transect, $request->user());

        return response()->json([
            'message' => 'Transect retrieved successfully.',
            'data' => new TransectResource($transect->load($this->resourceRelations())),
        ]);
    }

    public function update(UpdateTransectRequest $request, Transect $transect): JsonResponse
    {
        $this->abortUnlessCanAccess($transect, $request->user());

        DB::transaction(function () use ($request, $transect) {
            $this->persist($transect, $request->validated(), $request->user(), false);
        });

        return response()->json([
            'message' => 'Transect updated successfully.',
            'data' => new TransectResource($transect->load($this->resourceRelations())),
        ]);
    }

    public function destroy(Request $request, Transect $transect): JsonResponse
    {
        $this->abortUnlessCanAccess($transect, $request->user());
        $transect->delete();

        return response()->json(['message' => 'Transect deleted successfully.']);
    }

    private function persist(Transect $transect, array $data, User $user, bool $isStore): void
    {
        $points = $data['points'] ?? null;
        $handoffTarget = $data['target_distance_m'] ?? null;
        if ($handoffTarget !== null) {
            $contributions = $data['contributions'] ?? [];
            abort_if(empty($contributions), 422, 'A handed-off transect needs contributions.');
            $ids = array_column($contributions, 'id');
            abort_if(count($ids) !== count(array_unique($ids)), 422, 'Duplicate contribution IDs.');
            $completed = round(array_sum(array_map(fn ($item) => (float) ($item['distance_m'] ?? 0), $contributions)), 2);
            abort_if(abs($completed - (float) ($data['total_distance_m'] ?? -1)) > 0.1, 422, 'Transect distance does not match contributions.');
            abort_if(($data['status'] ?? null) !== 'completed' || $completed < (float) $handoffTarget,
                422, 'Only completed handed-off transects can be synchronized.');
        }
        $observationReferencesProvided = array_key_exists('observation_references', $data);
        $observationReferences = $data['observation_references'] ?? [];
        unset($data['points'], $data['observation_references']);

        if (! $transect->exists) {
            $transect->user_id = $user->id;
            $transect->transect_code = $this->generateTransectCode();
            $transect->status = $data['status'] ?? 'completed';
        }

        $transect->fill($data);
        $transect->user_id = $transect->user_id ?? $user->id;

        if ($points !== null) {
            $summary = $this->geometryService->summarize($points);
            $points = array_values($points);
            $first = $points[0];
            $last = $points[array_key_last($points)];
            $accuracies = collect($points)
                ->pluck('accuracy_m')
                ->filter(fn ($value) => is_numeric($value));

            $transect->start_latitude = $first['latitude'];
            $transect->start_longitude = $first['longitude'];
            $transect->end_latitude = $last['latitude'];
            $transect->end_longitude = $last['longitude'];
            $transect->total_distance_m = $summary['distance_m'];
            if ($handoffTarget !== null) {
                $transect->total_distance_m = $completed;
            }
            $transect->bearing_degrees = $summary['bearing_degrees'];
            $transect->geometry = $summary['geometry'];
            $transect->gps_accuracy_m = $accuracies->isNotEmpty()
                ? round((float) $accuracies->avg(), 2)
                : null;
        }

        if ($isStore || array_key_exists('recorded_at', $data)) {
            $transect->recorded_at = $data['recorded_at'] ?? now();
        }
        $transect->synced_at = now();
        $transect->save();

        if ($points !== null) {
            $transect->points()->delete();
            $transect->points()->createMany(array_map(
                fn (array $point, int $index) => [
                    'sequence_number' => $index + 1,
                    'latitude' => $point['latitude'],
                    'longitude' => $point['longitude'],
                    'accuracy_m' => $point['accuracy_m'] ?? null,
                    'altitude_m' => $point['altitude_m'] ?? null,
                    'recorded_at' => $point['recorded_at'] ?? null,
                ],
                $points,
                array_keys($points)
            ));
        }

        if ($observationReferencesProvided || $isStore) {
            [$observationIds, $unresolved] = $this->resolveObservationReferences(
                $observationReferences,
                $user
            );
            $transect->observations()->sync($observationIds);
            $transect->pending_observation_references = $unresolved ?: null;
            $transect->save();
        }
    }

    /**
     * @return array{0: array<int, int>, 1: array<int, string>}
     */
    private function resolveObservationReferences(array $references, User $user): array
    {
        $resolved = [];
        $unresolved = [];

        foreach (array_values(array_unique($references)) as $reference) {
            $record = null;

            try {
                $recordId = ApiId::decodeOrFail($reference);
                $record = ScanRecord::query()->find($recordId);
            } catch (InvalidArgumentException) {
                $record = ScanRecord::query()
                    ->where('offline_reference', $reference)
                    ->first();
            }

            if ($record && (ApiAccess::canViewAllRecords($user) || $record->user_id === $user->id)) {
                $resolved[] = $record->id;
            } else {
                $unresolved[] = $reference;
            }
        }

        return [array_values(array_unique($resolved)), $unresolved];
    }

    private function abortUnlessCanAccess(Transect $transect, ?User $user): void
    {
        if (ApiAccess::canViewAllRecords($user) || $transect->user_id === $user?->id) {
            return;
        }

        abort(404);
    }

    private function generateTransectCode(): string
    {
        $prefix = 'TR-' . Carbon::now()->format('Ymd') . '-';
        $lastCode = Transect::withTrashed()
            ->where('transect_code', 'like', "{$prefix}%")
            ->orderByDesc('transect_code')
            ->value('transect_code');
        $nextNumber = $lastCode ? ((int) substr($lastCode, -4)) + 1 : 1;

        do {
            $code = $prefix . str_pad((string) $nextNumber, 4, '0', STR_PAD_LEFT);
            $nextNumber++;
        } while (Transect::withTrashed()->where('transect_code', $code)->exists());

        return $code;
    }

    private function resourceRelations(): array
    {
        return [
            'user:id,name',
            'points',
            'observations.species',
            'observations.measurement',
            'observations.locationValidation',
            'observations.images',
        ];
    }
}
