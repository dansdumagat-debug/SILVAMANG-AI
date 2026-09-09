<?php

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreAssistantLogRequest;
use App\Http\Resources\AssistantLogResource;
use App\Models\AssistantLog;
use App\Models\ScanRecord;
use App\Http\Controllers\Controller;
use App\Support\ApiAccess;
use Illuminate\Support\Facades\Auth;

class AssistantLogController extends Controller
{
    public function index()
    {
        $assistantLogs = AssistantLog::query()
            ->when(! ApiAccess::canViewAllRecords(Auth::user()), fn ($query) => $query->where('user_id', Auth::id()))
            ->latest()
            ->get();

        return response()->json([
            'message' => 'Assistant log list retrieved successfully.',
            'data' => AssistantLogResource::collection($assistantLogs),
        ]);
    }

    public function store(StoreAssistantLogRequest $request)
    {
        $data = $request->validated();

        if (! empty($data['scan_record_id'])) {
            $scanRecord = ScanRecord::findOrFail($data['scan_record_id']);
            ApiAccess::abortUnlessCanAccessScanRecord($scanRecord, Auth::user());
        }

        if (ApiAccess::canViewAllRecords(Auth::user())) {
            $data['user_id'] = $data['user_id'] ?? Auth::id();
        } else {
            $data['user_id'] = Auth::id();
        }

        $assistantLog = AssistantLog::create($data);

        return response()->json([
            'message' => 'Assistant log created successfully.',
            'data' => new AssistantLogResource($assistantLog),
        ], 201);
    }

    public function show(AssistantLog $assistantLog)
    {
        if (! ApiAccess::canViewAllRecords(Auth::user()) && $assistantLog->user_id !== Auth::id()) {
            abort(404);
        }

        return response()->json([
            'message' => 'Assistant log retrieved successfully.',
            'data' => new AssistantLogResource($assistantLog),
        ]);
    }
}
