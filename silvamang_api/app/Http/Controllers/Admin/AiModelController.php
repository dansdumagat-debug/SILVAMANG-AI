<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AiModel;
use Illuminate\Http\Request;

class AiModelController extends Controller
{
    public function index()
    {
        $query = AiModel::query()
            ->when(request('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('model_name', 'like', "%{$search}%")
                        ->orWhere('model_type', 'like', "%{$search}%")
                        ->orWhere('version', 'like', "%{$search}%");
                });
            })
            ->when(request('model_type'), fn ($query, $type) => $query->where('model_type', $type))
            ->when(request('status'), fn ($query, $status) => $query->where('status', $status));

        return view('admin.ai-models.index', [
            'aiModels' => $query->orderBy('model_name')->paginate(10)->withQueryString(),
            'modelTypes' => AiModel::whereNotNull('model_type')->distinct()->orderBy('model_type')->pluck('model_type'),
            'statuses' => AiModel::whereNotNull('status')->distinct()->orderBy('status')->pluck('status'),
        ]);
    }

    public function create()
    {
        return view('admin.ai-models.create', [
            'aiModel' => new AiModel(['status' => 'inactive']),
        ]);
    }

    public function store(Request $request)
    {
        $aiModel = AiModel::create($this->validatedData($request));

        return redirect()
            ->route('admin.ai-models.show', $aiModel)
            ->with('success', 'AI model created successfully.');
    }

    public function show(AiModel $aiModel)
    {
        return view('admin.ai-models.show', [
            'aiModel' => $aiModel,
        ]);
    }

    public function edit(AiModel $aiModel)
    {
        return view('admin.ai-models.edit', [
            'aiModel' => $aiModel,
        ]);
    }

    public function update(Request $request, AiModel $aiModel)
    {
        $aiModel->update($this->validatedData($request));

        return redirect()
            ->route('admin.ai-models.show', $aiModel)
            ->with('success', 'AI model updated successfully.');
    }

    public function destroy(AiModel $aiModel)
    {
        $aiModel->delete();

        return redirect()
            ->route('admin.ai-models.index')
            ->with('success', 'AI model deleted successfully.');
    }

    private function validatedData(Request $request): array
    {
        return $request->validate([
            'model_name' => ['required', 'string', 'max:255'],
            'model_type' => ['required', 'string', 'max:100'],
            'version' => ['nullable', 'string', 'max:100'],
            'accuracy' => ['nullable', 'numeric', 'between:0,100'],
            'precision_score' => ['nullable', 'numeric', 'between:0,100'],
            'recall_score' => ['nullable', 'numeric', 'between:0,100'],
            'f1_score' => ['nullable', 'numeric', 'between:0,100'],
            'top_k_accuracy' => ['nullable', 'numeric', 'between:0,100'],
            'status' => ['required', 'string', 'max:50'],
            'deployed_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string'],
        ]);
    }
}
