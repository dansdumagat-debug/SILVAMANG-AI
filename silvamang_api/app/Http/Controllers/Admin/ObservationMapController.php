<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ScanRecord;
use App\Models\Species;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;

class ObservationMapController extends Controller
{
    private const ADMIN_CONSOLE_ROLES = ['super_admin', 'admin', 'researcher'];

    public function __invoke(Request $request): View
    {
        return $this->renderMap($request, false);
    }

    public function personal(Request $request): View
    {
        abort_unless($this->isMobileUserOnly($request->user()), 403);

        return $this->renderMap($request, true);
    }

    private function renderMap(Request $request, bool $isPersonalMap): View
    {
        $currentUser = $request->user();
        $mapScope = $isPersonalMap && $request->query('scope') === 'all' ? 'all' : 'mine';

        $query = ScanRecord::query()
            ->with(['user', 'species', 'measurement', 'locationValidation', 'images'])
            ->when($isPersonalMap && $mapScope === 'mine', fn (Builder $builder) => $builder->where('user_id', $currentUser->id))
            ->when($this->filterValue($request, 'search'), function (Builder $query, string $search) use ($isPersonalMap) {
                $query->where(function (Builder $builder) use ($search, $isPersonalMap) {
                    $builder
                        ->where('record_code', 'like', "%{$search}%")
                        ->orWhere('top_scientific_name', 'like', "%{$search}%")
                        ->orWhere('top_common_name', 'like', "%{$search}%")
                        ->orWhere('location_name', 'like', "%{$search}%")
                        ->orWhere('barangay', 'like', "%{$search}%")
                        ->orWhere('manual_barangay', 'like', "%{$search}%")
                        ->orWhereHas('user', function (Builder $userQuery) use ($search, $isPersonalMap) {
                            $userQuery->where('name', 'like', "%{$search}%");

                            if (! $isPersonalMap) {
                                $userQuery->orWhere('email', 'like', "%{$search}%");
                            }
                        });
                });
            })
            ->when($this->filterValue($request, 'species_id'), function (Builder $query, string $speciesId) {
                $species = Species::find($speciesId);

                $query->where(function (Builder $builder) use ($speciesId, $species) {
                    $builder->where('species_id', $speciesId);

                    if ($species) {
                        $builder->orWhere('top_scientific_name', $species->scientific_name);
                    }
                });
            })
            ->when($this->filterValue($request, 'barangay'), function (Builder $query, string $barangay) {
                $query->where(function (Builder $builder) use ($barangay) {
                    $builder
                        ->where('barangay', 'like', "%{$barangay}%")
                        ->orWhere('manual_barangay', 'like', "%{$barangay}%")
                        ->orWhere('location_name', 'like', "%{$barangay}%");
                });
            })
            ->when($this->filterValue($request, 'validation_status'), fn (Builder $query, string $status) => $query->where('validation_status', $status))
            ->when($this->filterValue($request, 'date_from'), function (Builder $query, string $date) {
                $query->where(function (Builder $builder) use ($date) {
                    $builder
                        ->whereDate('captured_at', '>=', $date)
                        ->orWhere(function (Builder $fallback) use ($date) {
                            $fallback
                                ->whereNull('captured_at')
                                ->whereDate('created_at', '>=', $date);
                        });
                });
            })
            ->when($this->filterValue($request, 'date_to'), function (Builder $query, string $date) {
                $query->where(function (Builder $builder) use ($date) {
                    $builder
                        ->whereDate('captured_at', '<=', $date)
                        ->orWhere(function (Builder $fallback) use ($date) {
                            $fallback
                                ->whereNull('captured_at')
                                ->whereDate('created_at', '<=', $date);
                        });
                });
            })
            ->when($this->filterValue($request, 'confidence_min'), fn (Builder $query, string $confidence) => $query->where('confidence', '>=', (float) $confidence))
            ->when($this->filterValue($request, 'confidence_max'), fn (Builder $query, string $confidence) => $query->where('confidence', '<=', (float) $confidence));

        if (! $isPersonalMap && ($userId = $this->filterValue($request, 'user_id'))) {
            $query->where('user_id', $userId);
        }

        $totalMatchingRecords = (clone $query)->count();
        $mappedMatchingRecords = $this->withMapCoordinates(clone $query)->count();
        $recordsWithoutCoordinates = $totalMatchingRecords - $mappedMatchingRecords;

        $records = $this->withMapCoordinates(clone $query)
            ->orderByRaw('COALESCE(captured_at, created_at) desc')
            ->limit(500)
            ->get();

        $markers = $records
            ->map(fn (ScanRecord $record) => $this->markerPayload($record, $currentUser, $isPersonalMap))
            ->values();

        return view('admin.observation-map.index', [
            'isPersonalMap' => $isPersonalMap,
            'mapScope' => $mapScope,
            'mapRoute' => $isPersonalMap ? 'admin.my-map' : 'admin.observation-map.index',
            'mapCounts' => $isPersonalMap ? $this->personalMapCounts($currentUser) : null,
            'markers' => $markers,
            'totalMatchingRecords' => $totalMatchingRecords,
            'recordsWithoutCoordinates' => $recordsWithoutCoordinates,
            'speciesOptions' => Species::orderBy('scientific_name')->get(['id', 'scientific_name']),
            'userOptions' => $isPersonalMap ? collect() : User::orderBy('name')->get(['id', 'name', 'email']),
            'validationStatuses' => ScanRecord::query()
                ->whereNotNull('validation_status')
                ->distinct()
                ->orderBy('validation_status')
                ->pluck('validation_status'),
        ]);
    }

    private function personalMapCounts(User $user): array
    {
        $myRecords = ScanRecord::query()->where('user_id', $user->id);
        $allRecords = ScanRecord::query();

        return [
            'my_scans' => (clone $myRecords)->count(),
            'my_pins' => $this->withMapCoordinates(clone $myRecords)->count(),
            'all_scans' => (clone $allRecords)->count(),
            'all_pins' => $this->withMapCoordinates(clone $allRecords)->count(),
        ];
    }

    private function markerPayload(ScanRecord $record, User $currentUser, bool $isPersonalMap): array
    {
        $image = $record->images->first();
        $imageUrl = null;

        if ($image?->image_path && Storage::disk('public')->exists($image->image_path)) {
            $imageUrl = asset('storage/' . $image->image_path);
        }

        $speciesName = $record->top_scientific_name
            ?? $record->species?->scientific_name
            ?? 'Unknown species';
        $observedAt = $record->captured_at ?? $record->created_at;
        $height = $record->height_m !== null
            ? (float) $record->height_m
            : ($record->measurement?->height_m !== null ? (float) $record->measurement->height_m : null);
        $canopyWidth = $record->canopy_width_m !== null
            ? (float) $record->canopy_width_m
            : ($record->measurement?->canopy_width_m !== null ? (float) $record->measurement->canopy_width_m : null);

        return [
            'id' => $record->id,
            'record_code' => $record->record_code,
            'species' => $speciesName,
            'common_name' => $record->top_common_name ?? $record->species?->common_name,
            'confidence' => $record->confidence !== null ? (float) $record->confidence : null,
            'latitude' => (float) ($record->latitude ?? $record->locationValidation?->latitude),
            'longitude' => (float) ($record->longitude ?? $record->locationValidation?->longitude),
            'accuracy' => $record->accuracy !== null ? (float) $record->accuracy : null,
            'barangay' => $record->barangay ?: $record->manual_barangay ?: $record->location_name,
            'validation_status' => $record->validation_status,
            'height_m' => $height,
            'canopy_width_m' => $canopyWidth,
            'sync_status' => $record->synced_at ? 'synced' : ($record->offline_reference ? 'pending_sync' : 'online'),
            'is_mine' => $record->user_id === $currentUser->id,
            'user' => $record->user
                ? ($isPersonalMap ? $record->user->name : "{$record->user->name} ({$record->user->email})")
                : 'N/A',
            'captured_at' => $observedAt?->format('M d, Y h:i A'),
            'captured_date' => $observedAt?->format('F d, Y'),
            'captured_time' => $observedAt?->format('h:i A'),
            'created_at' => $record->created_at?->format('M d, Y h:i A'),
            'synced_at' => $record->synced_at?->format('M d, Y h:i A'),
            'image_url' => $imageUrl,
            'detail_url' => $isPersonalMap ? null : route('admin.scan-monitoring.show', $record),
        ];
    }

    private function filterValue(Request $request, string $key): ?string
    {
        $value = trim((string) $request->query($key, ''));

        return $value === '' ? null : $value;
    }

    private function withMapCoordinates(Builder $query): Builder
    {
        return $query->where(function (Builder $builder) {
            $builder
                ->where(function (Builder $scanCoordinates) {
                    $scanCoordinates->whereNotNull('latitude')->whereNotNull('longitude');
                })
                ->orWhereHas('locationValidation', function (Builder $validationCoordinates) {
                    $validationCoordinates->whereNotNull('latitude')->whereNotNull('longitude');
                });
        });
    }

    private function isMobileUserOnly(?User $user): bool
    {
        return (bool) $user?->hasRole('mobile_user')
            && ! $user->hasAnyRole(self::ADMIN_CONSOLE_ROLES);
    }
}
