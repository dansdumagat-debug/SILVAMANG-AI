<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AssistantLog;

class AssistantLogController extends Controller
{
    public function index()
    {
        $query = AssistantLog::query()
            ->with('user')
            ->when(request('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('question', 'like', "%{$search}%")
                        ->orWhere('response', 'like', "%{$search}%")
                        ->orWhereHas('user', fn ($query) => $query->where('name', 'like', "%{$search}%"));
                });
            })
            ->when(request('intent'), fn ($query, $intent) => $query->where('intent', $intent))
            ->when(request('source'), fn ($query, $source) => $query->where('source', $source))
            ->when(request('date_from'), fn ($query, $date) => $query->whereDate('created_at', '>=', $date))
            ->when(request('date_to'), fn ($query, $date) => $query->whereDate('created_at', '<=', $date));

        return view('admin.assistant-logs.index', [
            'assistantLogs' => $query->latest()->paginate(10)->withQueryString(),
            'intents' => AssistantLog::whereNotNull('intent')->distinct()->orderBy('intent')->pluck('intent'),
            'sources' => AssistantLog::whereNotNull('source')->distinct()->orderBy('source')->pluck('source'),
        ]);
    }

    public function show(AssistantLog $assistantLog)
    {
        $assistantLog->load(['user', 'scanRecord.species']);

        return view('admin.assistant-logs.show', compact('assistantLog'));
    }
}
