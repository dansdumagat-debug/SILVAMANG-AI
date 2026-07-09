<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreAssistantLogRequest;
use App\Http\Resources\AssistantLogResource;
use App\Models\AssistantLog;
use App\Http\Controllers\Controller;

class AssistantLogController extends Controller
{
    public function index()
    {
        $assistantLogs = AssistantLog::query()
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Assistant log list retrieved successfully.',
            'data' => AssistantLogResource::collection($assistantLogs),
        ]);
    }

    public function store(StoreAssistantLogRequest $request)
    {
        $assistantLog = AssistantLog::create($request->validated());

        return response()->json([
            'message' => 'Assistant log created successfully.',
            'data' => new AssistantLogResource($assistantLog),
        ], 201);
    }

    public function show(AssistantLog $assistantLog)
    {
        return response()->json([
            'message' => 'Assistant log retrieved successfully.',
            'data' => new AssistantLogResource($assistantLog),
        ]);
    }
}
