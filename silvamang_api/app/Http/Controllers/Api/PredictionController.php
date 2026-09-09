<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StorePredictionRequest;
use App\Http\Resources\PredictionResource;
use App\Models\Prediction;
use App\Models\ScanRecord;
use App\Http\Controllers\Controller;
use App\Support\ApiAccess;
use Illuminate\Support\Facades\Auth;

class PredictionController extends Controller
{
    public function index()
    {
        $predictions = Prediction::query()
            ->with(['scanRecord', 'species'])
            ->whereHas('scanRecord', fn ($query) => ApiAccess::scopeScanRecords($query, Auth::user()))
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Prediction list retrieved successfully.',
            'data' => PredictionResource::collection($predictions),
        ]);
    }

    public function store(StorePredictionRequest $request)
    {
        $data = $request->validated();
        $scanRecord = ScanRecord::findOrFail($data['scan_record_id']);
        ApiAccess::abortUnlessCanAccessScanRecord($scanRecord, Auth::user());

        $prediction = Prediction::create($data);

        return response()->json([
            'message' => 'Prediction created successfully.',
            'data' => new PredictionResource($prediction->load(['scanRecord', 'species'])),
        ], 201);
    }

    public function show(Prediction $prediction)
    {
        $prediction->load('scanRecord');
        ApiAccess::abortUnlessCanAccessScanRecord($prediction->scanRecord, Auth::user());

        return response()->json([
            'message' => 'Prediction retrieved successfully.',
            'data' => new PredictionResource($prediction->load(['scanRecord', 'species'])),
        ]);
    }
}
