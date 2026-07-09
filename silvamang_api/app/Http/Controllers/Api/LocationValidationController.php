<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreLocationValidationRequest;
use App\Http\Resources\LocationValidationResource;
use App\Models\LocationValidation;
use App\Models\ScanRecord;
use App\Services\LocationValidationService;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class LocationValidationController extends Controller
{
    public function index(Request $request)
    {
        $locationValidations = LocationValidation::query()
            ->with(['scanRecord', 'species'])
            ->when($request->query('result'), fn ($query, $result) => $query->where('result', $result))
            ->when($request->query('species_id'), fn ($query, $speciesId) => $query->where('species_id', $speciesId))
            ->when($request->query('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('message', 'like', "%{$search}%")
                        ->orWhereHas('scanRecord', fn ($query) => $query->where('record_code', 'like', "%{$search}%"))
                        ->orWhereHas('species', fn ($query) => $query->where('scientific_name', 'like', "%{$search}%"));
                });
            })
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Location validation list retrieved successfully.',
            'data' => LocationValidationResource::collection($locationValidations),
        ]);
    }

    public function store(StoreLocationValidationRequest $request, LocationValidationService $service)
    {
        $data = $request->validated();
        $scanRecord = ScanRecord::findOrFail($data['scan_record_id']);
        $speciesId = $data['species_id'] ?? $scanRecord->species_id;
        $latitude = array_key_exists('latitude', $data) ? $data['latitude'] : $scanRecord->latitude;
        $longitude = array_key_exists('longitude', $data) ? $data['longitude'] : $scanRecord->longitude;
        $validation = $service->validateSpeciesLocation(
            $speciesId,
            $latitude !== null ? (float) $latitude : null,
            $longitude !== null ? (float) $longitude : null
        );

        $locationValidation = LocationValidation::updateOrCreate(
            ['scan_record_id' => $scanRecord->id],
            [
                'species_id' => $speciesId,
                'latitude' => $latitude,
                'longitude' => $longitude,
                'result' => $validation['result'],
                'distance_to_known_distribution_km' => $validation['distance_to_known_distribution_km'],
                'message' => $validation['message'],
                'validated_at' => $data['validated_at'] ?? now(),
            ]
        );

        $scanRecord->update(['validation_status' => $validation['result']]);

        return response()->json([
            'message' => 'Location validation completed successfully.',
            'data' => new LocationValidationResource($locationValidation->load(['scanRecord', 'species'])),
        ], $locationValidation->wasRecentlyCreated ? 201 : 200);
    }

    public function show(LocationValidation $locationValidation)
    {
        return response()->json([
            'message' => 'Location validation retrieved successfully.',
            'data' => new LocationValidationResource($locationValidation->load(['scanRecord', 'species'])),
        ]);
    }
}
