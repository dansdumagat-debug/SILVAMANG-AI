<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreSpeciesRequest;
use App\Http\Requests\UpdateSpeciesRequest;
use App\Http\Resources\SpeciesResource;
use App\Models\Species;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class SpeciesController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $species = Species::query()
            ->with(['images', 'distributions'])
            ->when(request('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('scientific_name', 'like', "%{$search}%")
                        ->orWhere('common_name', 'like', "%{$search}%");
                });
            })
            ->when(request('status'), fn ($query, $status) => $query->where('status', $status))
            ->when(request('family'), fn ($query, $family) => $query->where('family', $family))
            ->when(request('conservation_status'), fn ($query, $status) => $query->where('conservation_status', $status))
            ->orderBy('scientific_name')
            ->get();

        return response()->json([
            'message' => 'Species list retrieved successfully.',
            'data' => SpeciesResource::collection($species),
        ]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(StoreSpeciesRequest $request)
    {
        $species = Species::create($request->validated());

        return response()->json([
            'message' => 'Species created successfully.',
            'data' => new SpeciesResource($species->load(['images', 'distributions'])),
        ], 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(Species $species)
    {
        return response()->json([
            'message' => 'Species retrieved successfully.',
            'data' => new SpeciesResource($species->load(['images', 'distributions'])),
        ]);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(UpdateSpeciesRequest $request, Species $species)
    {
        $species->update($request->validated());

        return response()->json([
            'message' => 'Species updated successfully.',
            'data' => new SpeciesResource($species->load(['images', 'distributions'])),
        ]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(Species $species)
    {
        $species->delete();

        return response()->json([
            'message' => 'Species deleted successfully.',
        ]);
    }
}
