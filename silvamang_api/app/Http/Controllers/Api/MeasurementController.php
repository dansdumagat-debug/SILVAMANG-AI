<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreMeasurementRequest;
use App\Http\Resources\MeasurementResource;
use App\Models\Measurement;
use App\Models\ScanRecord;
use App\Http\Controllers\Controller;
use App\Support\ApiAccess;
use Illuminate\Support\Facades\Auth;

class MeasurementController extends Controller
{
    public function index()
    {
        $measurements = Measurement::query()
            ->with('scanRecord')
            ->whereHas('scanRecord', fn ($query) => ApiAccess::scopeScanRecords($query, Auth::user()))
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Measurement list retrieved successfully.',
            'data' => MeasurementResource::collection($measurements),
        ]);
    }

    public function store(StoreMeasurementRequest $request)
    {
        $data = $request->validated();
        $scanRecord = ScanRecord::findOrFail($data['scan_record_id']);
        ApiAccess::abortUnlessCanAccessScanRecord($scanRecord, Auth::user());

        $measurementData = collect($data)
            ->except('scan_record_id')
            ->reject(fn ($value, $key) => in_array($key, ['height_m', 'canopy_width_m', 'dbh_cm'], true) && $value === null)
            ->all();

        $measurement = Measurement::updateOrCreate(
            ['scan_record_id' => $scanRecord->id],
            $measurementData
        );

        $scanRecordUpdates = [];
        foreach (['height_m', 'canopy_width_m'] as $field) {
            if (array_key_exists($field, $measurementData) && $measurementData[$field] !== null) {
                $scanRecordUpdates[$field] = $measurementData[$field];
            }
        }

        if ($scanRecordUpdates !== []) {
            $scanRecord->forceFill($scanRecordUpdates)->save();
        }

        return response()->json([
            'message' => 'Measurement created successfully.',
            'data' => new MeasurementResource($measurement->load('scanRecord')),
        ], 201);
    }

    public function show(Measurement $measurement)
    {
        $measurement->load('scanRecord');
        ApiAccess::abortUnlessCanAccessScanRecord($measurement->scanRecord, Auth::user());

        return response()->json([
            'message' => 'Measurement retrieved successfully.',
            'data' => new MeasurementResource($measurement->load('scanRecord')),
        ]);
    }
}
