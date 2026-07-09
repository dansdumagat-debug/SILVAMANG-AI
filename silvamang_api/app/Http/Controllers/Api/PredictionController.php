<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StorePredictionRequest;
use App\Http\Resources\PredictionResource;
use App\Models\Prediction;
use App\Http\Controllers\Controller;

class PredictionController extends Controller
{
    public function index()
    {
        $predictions = Prediction::query()
            ->with('species')
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Prediction list retrieved successfully.',
            'data' => PredictionResource::collection($predictions),
        ]);
    }

    public function store(StorePredictionRequest $request)
    {
        $prediction = Prediction::create($request->validated());

        return response()->json([
            'message' => 'Prediction created successfully.',
            'data' => new PredictionResource($prediction->load('species')),
        ], 201);
    }

    public function show(Prediction $prediction)
    {
        return response()->json([
            'message' => 'Prediction retrieved successfully.',
            'data' => new PredictionResource($prediction->load('species')),
        ]);
    }
}
