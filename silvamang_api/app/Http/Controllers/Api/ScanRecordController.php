<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreScanRecordRequest;
use App\Http\Requests\UpdateScanRecordRequest;
use App\Http\Resources\ScanRecordResource;
use App\Models\LocationValidation;
use App\Models\ScanRecord;
use App\Services\LocationValidationService;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Carbon;

class ScanRecordController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $scanRecords = ScanRecord::query()
            ->with(['species', 'images', 'predictions.species', 'measurement', 'locationValidation.species'])
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
            ->when(request('date_from'), fn ($query, $date) => $query->whereDate('captured_at', '>=', $date))
            ->when(request('date_to'), fn ($query, $date) => $query->whereDate('captured_at', '<=', $date))
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Scan record list retrieved successfully.',
            'data' => ScanRecordResource::collection($scanRecords),
        ]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(StoreScanRecordRequest $request)
    {
        $data = $request->validated();
        $data['record_code'] = $data['record_code'] ?? $this->generateRecordCode();
        $data['user_id'] = $data['user_id'] ?? Auth::id();

        $scanRecord = ScanRecord::create($data);

        return response()->json([
            'message' => 'Scan record created successfully.',
            'data' => new ScanRecordResource($scanRecord->load(['species', 'images', 'predictions.species', 'measurement', 'locationValidation.species'])),
        ], 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(ScanRecord $scanRecord)
    {
        return response()->json([
            'message' => 'Scan record retrieved successfully.',
            'data' => new ScanRecordResource($scanRecord->load(['species', 'images', 'predictions.species', 'measurement', 'locationValidation.species'])),
        ]);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(UpdateScanRecordRequest $request, ScanRecord $scanRecord)
    {
        $scanRecord->update($request->validated());

        return response()->json([
            'message' => 'Scan record updated successfully.',
            'data' => new ScanRecordResource($scanRecord->load(['species', 'images', 'predictions.species', 'measurement', 'locationValidation.species'])),
        ]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(ScanRecord $scanRecord)
    {
        $scanRecord->delete();

        return response()->json([
            'message' => 'Scan record deleted successfully.',
        ]);
    }

    public function validateLocation(ScanRecord $scanRecord, LocationValidationService $service)
    {
        $validation = $service->validateSpeciesLocation(
            $scanRecord->species_id,
            $scanRecord->latitude !== null ? (float) $scanRecord->latitude : null,
            $scanRecord->longitude !== null ? (float) $scanRecord->longitude : null
        );

        LocationValidation::updateOrCreate(
            ['scan_record_id' => $scanRecord->id],
            [
                'species_id' => $scanRecord->species_id,
                'latitude' => $scanRecord->latitude,
                'longitude' => $scanRecord->longitude,
                'result' => $validation['result'],
                'distance_to_known_distribution_km' => $validation['distance_to_known_distribution_km'],
                'message' => $validation['message'],
                'validated_at' => now(),
            ]
        );

        $scanRecord->update(['validation_status' => $validation['result']]);

        return response()->json([
            'message' => 'Location validation completed successfully.',
            'data' => new ScanRecordResource($scanRecord->load(['species', 'images', 'predictions.species', 'measurement', 'locationValidation.species'])),
        ]);
    }

    private function generateRecordCode(): string
    {
        $date = Carbon::now()->format('Ymd');
        $prefix = "SC-{$date}-";
        $lastRecord = ScanRecord::withTrashed()
            ->where('record_code', 'like', "{$prefix}%")
            ->orderByDesc('record_code')
            ->first();

        $nextNumber = $lastRecord ? ((int) substr($lastRecord->record_code, -4)) + 1 : 1;

        do {
            $code = $prefix . str_pad((string) $nextNumber, 4, '0', STR_PAD_LEFT);
            $nextNumber++;
        } while (ScanRecord::withTrashed()->where('record_code', $code)->exists());

        return $code;
    }
}
