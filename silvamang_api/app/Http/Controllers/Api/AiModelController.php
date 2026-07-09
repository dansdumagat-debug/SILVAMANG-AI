<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreAiModelRequest;
use App\Http\Requests\UpdateAiModelRequest;
use App\Http\Resources\AiModelResource;
use App\Models\AiModel;
use App\Http\Controllers\Controller;

class AiModelController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $models = AiModel::query()
            ->when(request('model_type'), fn ($query, $type) => $query->where('model_type', $type))
            ->when(request('status'), fn ($query, $status) => $query->where('status', $status))
            ->orderBy('model_name')
            ->get();

        return response()->json([
            'message' => 'AI model list retrieved successfully.',
            'data' => AiModelResource::collection($models),
        ]);
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(StoreAiModelRequest $request)
    {
        $aiModel = AiModel::create($request->validated());

        return response()->json([
            'message' => 'AI model created successfully.',
            'data' => new AiModelResource($aiModel),
        ], 201);
    }

    /**
     * Display the specified resource.
     */
    public function show(AiModel $aiModel)
    {
        return response()->json([
            'message' => 'AI model retrieved successfully.',
            'data' => new AiModelResource($aiModel),
        ]);
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(UpdateAiModelRequest $request, AiModel $aiModel)
    {
        $aiModel->update($request->validated());

        return response()->json([
            'message' => 'AI model updated successfully.',
            'data' => new AiModelResource($aiModel),
        ]);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy(AiModel $aiModel)
    {
        $aiModel->delete();

        return response()->json([
            'message' => 'AI model deleted successfully.',
        ]);
    }
}
