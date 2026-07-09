<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreMeasurementRequest;
use App\Http\Resources\MeasurementResource;
use App\Models\Measurement;
use App\Http\Controllers\Controller;

class MeasurementController extends Controller
{
    public function index()
    {
        $measurements = Measurement::query()
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Measurement list retrieved successfully.',
            'data' => MeasurementResource::collection($measurements),
        ]);
    }

    public function store(StoreMeasurementRequest $request)
    {
        $measurement = Measurement::create($request->validated());

        return response()->json([
            'message' => 'Measurement created successfully.',
            'data' => new MeasurementResource($measurement),
        ], 201);
    }

    public function show(Measurement $measurement)
    {
        return response()->json([
            'message' => 'Measurement retrieved successfully.',
            'data' => new MeasurementResource($measurement),
        ]);
    }
}
