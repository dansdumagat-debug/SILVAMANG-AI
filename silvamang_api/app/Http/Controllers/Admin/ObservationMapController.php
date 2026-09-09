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
    public function __invoke(Request $request): View
    {
        $query = ScanRecord::query()
            ->with(['user', 'species', 'measurement', 'locationValidation', 'images'])
            ->when($this->filterValue($request, 'search'), function (Builder $query, string $search) {
                $query->where(function (Builder $builder) use ($search) {
                    $builder
                        ->where('record_code', 'like', "%{$search}%")
                        ->orWhere('top_scientific_name', 'like', "%{$search}%")
                        ->orWhere('top_common_name', 'like', "%{$search}%")
                        ->orWhere('location_name', 'like', "%{$search}%")
                        ->orWhere('barangay', 'like', "%{$search}%")
                        ->orWhere('manual_barangay', 'like', "%{$search}%")
                        ->orWhereHas('user', function (Builder $userQuery) use ($search) {
                            $userQuery
                                ->where('name', 'like', "%{$search}%")
                                ->orWhere('email', 'like', "%{$search}%");
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
            ->when($this->filterValue($request, 'user_id'), fn (Builder $query, string $userId) => $query->where('user_id', $userId))
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

        $totalMatchingRecords = (clone $query)->count();
        $recordsWithoutCoordinates = (clone $query)
            ->where(function (Builder $builder) {
                $builder->whereNull('latitude')->orWhereNull('longitude');
            })
            ->count();

        $records = (clone $query)
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->orderByRaw('COALESCE(captured_at, created_at) desc')
            ->limit(500)
            ->get();

        $markers = $records->map(fn (ScanRecord $record) => $this->markerPayload($record))->values();

        return view('admin.observation-map.index', [
            'markers' => $markers,
            'totalMatchingRecords' => $totalMatchingRecords,
            'recordsWithoutCoordinates' => $recordsWithoutCoordinates,
            'speciesOptions' => Species::orderBy('scientific_name')->get(['id', 'scientific_name']),
            'userOptions' => User::orderBy('name')->get(['id', 'name', 'email']),
            'validationStatuses' => ScanRecord::query()
                ->whereNotNull('validation_status')
                ->distinct()
                ->orderBy('validation_status')
                ->pluck('validation_status'),
        ]);
    }

    private function markerPayload(ScanRecord $record): array
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
            'latitude' => (float) $record->latitude,
            'longitude' => (float) $record->longitude,
            'accuracy' => $record->accuracy !== null ? (float) $record->accuracy : null,
            'barangay' => $record->barangay ?: $record->manual_barangay ?: $record->location_name,
            'validation_status' => $record->validation_status,
            'height_m' => $height,
            'canopy_width_m' => $canopyWidth,
            'sync_status' => $record->synced_at ? 'synced' : ($record->offline_reference ? 'pending_sync' : 'online'),
            'user' => $record->user ? "{$record->user->name} ({$record->user->email})" : 'N/A',
            'user_name' => $record->user?->name,
            'user_email' => $record->user?->email,
            'captured_at' => $observedAt?->format('M d, Y h:i A'),
            'captured_date' => $observedAt?->format('F d, Y'),
            'captured_time' => $observedAt?->format('h:i A'),
            'created_at' => $record->created_at?->format('M d, Y h:i A'),
            'synced_at' => $record->synced_at?->format('M d, Y h:i A'),
            'image_url' => $imageUrl,
            'detail_url' => route('admin.scan-monitoring.show', $record),
        ];
    }

    private function filterValue(Request $request, string $key): ?string
    {
        $value = trim((string) $request->query($key, ''));

        return $value === '' ? null : $value;
    }
}
