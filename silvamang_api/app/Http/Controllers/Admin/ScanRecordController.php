<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ScanRecord;
use App\Models\Species;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;

class ScanRecordController extends Controller
{
    public function index(Request $request)
    {
        $query = ScanRecord::query()
            ->with(['user', 'species', 'measurement', 'locationValidation', 'images'])
            ->when($this->filterValue($request, 'search'), function (Builder $query, string $search) {
                $query->where(function (Builder $query) use ($search) {
                    $query
                        ->where('record_code', 'like', "%{$search}%")
                        ->orWhere('top_scientific_name', 'like', "%{$search}%")
                        ->orWhere('top_common_name', 'like', "%{$search}%")
                        ->orWhere('location_name', 'like', "%{$search}%")
                        ->orWhere('barangay', 'like', "%{$search}%")
                        ->orWhere('manual_barangay', 'like', "%{$search}%")
                        ->orWhere('address', 'like', "%{$search}%")
                        ->orWhereHas('user', function (Builder $userQuery) use ($search) {
                            $userQuery
                                ->where('name', 'like', "%{$search}%")
                                ->orWhere('email', 'like', "%{$search}%");
                        })
                        ->orWhereHas('species', function (Builder $speciesQuery) use ($search) {
                            $speciesQuery
                                ->where('scientific_name', 'like', "%{$search}%")
                                ->orWhere('common_name', 'like', "%{$search}%");
                        });
                });
            })
            ->when($this->filterValue($request, 'species_id'), fn (Builder $query, string $speciesId) => $query->where('species_id', $speciesId))
            ->when($this->filterValue($request, 'user_id'), fn (Builder $query, string $userId) => $query->where('user_id', $userId))
            ->when($this->filterValue($request, 'identification_status'), fn (Builder $query, string $status) => $query->where('identification_status', $status))
            ->when($this->filterValue($request, 'validation_status'), fn (Builder $query, string $status) => $query->where('validation_status', $status))
            ->when($this->filterValue($request, 'location'), function (Builder $query, string $location) {
                $query->where(function (Builder $builder) use ($location) {
                    $builder
                        ->where('location_name', 'like', "%{$location}%")
                        ->orWhere('barangay', 'like', "%{$location}%")
                        ->orWhere('manual_barangay', 'like', "%{$location}%")
                        ->orWhere('address', 'like', "%{$location}%");
                });
            })
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
            });

        $this->applySort($query, $this->filterValue($request, 'sort') ?? 'latest_scan');

        return view('admin.scan-records.index', [
            'scanRecords' => $query->paginate(15)->withQueryString(),
            'totalScanRecords' => ScanRecord::count(),
            'mappedScanRecords' => ScanRecord::whereNotNull('latitude')->whereNotNull('longitude')->count(),
            'todayScanRecords' => ScanRecord::where(function (Builder $builder) {
                $builder
                    ->whereDate('captured_at', now()->toDateString())
                    ->orWhere(function (Builder $fallback) {
                        $fallback
                            ->whereNull('captured_at')
                            ->whereDate('created_at', now()->toDateString());
                    });
            })->count(),
            'speciesOptions' => Species::orderBy('scientific_name')->get(['id', 'scientific_name']),
            'userOptions' => User::orderBy('name')->get(['id', 'name', 'email']),
            'identificationStatuses' => ScanRecord::whereNotNull('identification_status')->distinct()->orderBy('identification_status')->pluck('identification_status'),
            'validationStatuses' => ScanRecord::whereNotNull('validation_status')->distinct()->orderBy('validation_status')->pluck('validation_status'),
            'sortOptions' => [
                'latest_scan' => 'Latest scan date',
                'oldest_scan' => 'Oldest scan date',
                'user' => 'User',
                'species' => 'Species',
                'location' => 'Location',
                'confidence' => 'Confidence',
            ],
        ]);
    }

    public function show(ScanRecord $scanRecord)
    {
        $scanRecord->load([
            'user',
            'species',
            'images.verifiedSpecies',
            'images.verifier',
            'predictions',
            'measurement',
            'locationValidation',
            'assistantLogs',
        ]);

        return view('admin.scan-records.show', compact('scanRecord'));
    }

    private function applySort(Builder $query, string $sort): void
    {
        match ($sort) {
            'oldest_scan' => $query->orderByRaw('COALESCE(captured_at, created_at) asc'),
            'user' => $query
                ->orderBy(User::select('name')->whereColumn('users.id', 'scan_records.user_id')->limit(1))
                ->orderByRaw('COALESCE(captured_at, created_at) desc'),
            'species' => $query
                ->orderBy(Species::select('scientific_name')->whereColumn('species.id', 'scan_records.species_id')->limit(1))
                ->orderBy('top_scientific_name')
                ->orderByRaw('COALESCE(captured_at, created_at) desc'),
            'location' => $query
                ->orderByRaw('COALESCE(barangay, manual_barangay, location_name, address, "") asc')
                ->orderByRaw('COALESCE(captured_at, created_at) desc'),
            'confidence' => $query
                ->orderByDesc('confidence')
                ->orderByRaw('COALESCE(captured_at, created_at) desc'),
            default => $query->orderByRaw('COALESCE(captured_at, created_at) desc'),
        };
    }

    private function filterValue(Request $request, string $key): ?string
    {
        $value = trim((string) $request->query($key, ''));

        return $value === '' ? null : $value;
    }
}
