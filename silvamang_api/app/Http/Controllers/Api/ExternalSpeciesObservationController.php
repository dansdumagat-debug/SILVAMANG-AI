<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ExternalSpeciesObservationResource;
use App\Models\Species;
use App\Services\INaturalistService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ExternalSpeciesObservationController extends Controller
{
    public function index(Request $request, INaturalistService $service): JsonResponse
    {
        $data = $request->validate([
            'species_name' => ['required', 'string', 'max:255'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:20'],
            'refresh' => ['nullable', 'boolean'],
        ]);

        $result = $service->getSpeciesObservations(
            speciesName: $data['species_name'],
            limit: $data['limit'] ?? null,
            refresh: $request->boolean('refresh'),
        );

        return $this->referenceResponse($result, $data['species_name']);
    }

    public function show(Species $species, Request $request, INaturalistService $service): JsonResponse
    {
        $data = $request->validate([
            'limit' => ['nullable', 'integer', 'min:1', 'max:20'],
            'refresh' => ['nullable', 'boolean'],
        ]);

        $result = $service->getSpeciesObservations(
            speciesName: $species->scientific_name,
            species: $species,
            limit: $data['limit'] ?? null,
            refresh: $request->boolean('refresh'),
        );

        return $this->referenceResponse($result, $species->scientific_name);
    }

    private function referenceResponse(array $result, string $speciesName): JsonResponse
    {
        $observations = $result['observations'] ?? collect();

        return response()->json([
            'message' => $result['message'] ?? 'External biodiversity references loaded.',
            'data' => [
                'status' => $result['status'] ?? 'unknown',
                'source' => $result['source'] ?? 'inaturalist',
                'species_name' => $speciesName,
                'cached' => (bool) ($result['cached'] ?? true),
                'observation_count' => (int) ($result['observation_count'] ?? $observations->count()),
                'photos_count' => (int) ($result['photos_count'] ?? $observations->whereNotNull('photo_url')->count()),
                'last_synced_at' => $result['last_synced_at'] ?? null,
                'imported_count' => (int) ($result['imported_count'] ?? 0),
                'observations' => ExternalSpeciesObservationResource::collection($observations),
            ],
        ]);
    }
}
