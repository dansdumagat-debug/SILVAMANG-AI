<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreAlertRequest;
use App\Http\Requests\UpdateAlertRequest;
use App\Http\Resources\AlertResource;
use App\Models\Alert;
use App\Http\Controllers\Controller;

class AlertController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $alerts = Alert::query()
            ->with('relatedScanRecord')
            ->when(request('severity'), fn ($query, $severity) => $query->where('severity', $severity))
            ->when(request('status'), fn ($query, $status) => $query->where('status', $status))
            ->when(request('alert_type'), fn ($query, $type) => $query->where('alert_type', $type))
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Alert list retrieved successfully.',
            'data' => AlertResource::collection($alerts),
        ]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(StoreAlertRequest $request)
    {
        $alert = Alert::create($request->validated());

        return response()->json([
            'message' => 'Alert created successfully.',
            'data' => new AlertResource($alert->load('relatedScanRecord')),
        ], 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(Alert $alert)
    {
        return response()->json([
            'message' => 'Alert retrieved successfully.',
            'data' => new AlertResource($alert->load('relatedScanRecord')),
        ]);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(UpdateAlertRequest $request, Alert $alert)
    {
        $alert->update($request->validated());

        return response()->json([
            'message' => 'Alert updated successfully.',
            'data' => new AlertResource($alert->load('relatedScanRecord')),
        ]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(Alert $alert)
    {
        $alert->delete();

        return response()->json([
            'message' => 'Alert deleted successfully.',
        ]);
    }
}
