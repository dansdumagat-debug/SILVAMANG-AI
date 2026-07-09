<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ScanRecord;
use App\Models\Species;

class ScanRecordController extends Controller
{
    public function index()
    {
        $query = ScanRecord::query()
            ->with('species')
            ->when(request('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('record_code', 'like', "%{$search}%")
                        ->orWhere('top_scientific_name', 'like', "%{$search}%")
                        ->orWhere('top_common_name', 'like', "%{$search}%")
                        ->orWhere('location_name', 'like', "%{$search}%");
                });
            })
            ->when(request('species_id'), fn ($query, $speciesId) => $query->where('species_id', $speciesId))
            ->when(request('identification_status'), fn ($query, $status) => $query->where('identification_status', $status))
            ->when(request('validation_status'), fn ($query, $status) => $query->where('validation_status', $status))
            ->when(request('date_from'), fn ($query, $date) => $query->whereDate('created_at', '>=', $date))
            ->when(request('date_to'), fn ($query, $date) => $query->whereDate('created_at', '<=', $date));

        return view('admin.scan-records.index', [
            'scanRecords' => $query->latest()->paginate(10)->withQueryString(),
            'speciesOptions' => Species::orderBy('scientific_name')->get(['id', 'scientific_name']),
            'identificationStatuses' => ScanRecord::whereNotNull('identification_status')->distinct()->orderBy('identification_status')->pluck('identification_status'),
            'validationStatuses' => ScanRecord::whereNotNull('validation_status')->distinct()->orderBy('validation_status')->pluck('validation_status'),
        ]);
    }

    public function show(ScanRecord $scanRecord)
    {
        $scanRecord->load([
            'user',
            'species',
            'images',
            'predictions',
            'measurement',
            'locationValidation',
            'assistantLogs',
        ]);

        return view('admin.scan-records.show', compact('scanRecord'));
    }
}
