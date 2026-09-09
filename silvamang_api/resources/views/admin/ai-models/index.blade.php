@extends('admin.layouts.app')

@section('title', 'AI Models')

@section('content')
    <div class="card mb-4">
        <div class="card-header d-flex align-items-center justify-content-between">
            <div>
                <h5 class="mb-0">AI Model Runtime Health</h5>
                <small class="text-muted">Checks Python AI service availability for each registered model endpoint.</small>
            </div>
        </div>

        <div class="card-body">
            <div class="table-responsive">
                <table class="table align-middle mb-0">
                    <thead>
                        <tr>
                            <th>Model name</th>
                            <th>Type</th>
                            <th>Version</th>
                            <th>Accuracy</th>
                            <th>Evaluation metrics</th>
                            <th>Status</th>
                            <th>Endpoint</th>
                            <th>Health</th>
                            <th>Last checked</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($aiModels as $aiModel)
                            @php($health = $modelHealth[$aiModel->id] ?? null)
                            @php($evaluations = collect($modelEvaluations[$aiModel->id] ?? []))
                            @php($accuracyEvaluation = $evaluations->firstWhere('metric_name', 'accuracy'))
                            <tr>
                                <td>{{ $aiModel->model_name }}</td>
                                <td>{{ $aiModel->model_type }}</td>
                                <td>{{ $health['version'] ?? $aiModel->version ?? 'Not available' }}</td>
                                <td>
                                    @if ($accuracyEvaluation)
                                        {{ $accuracyEvaluation->display_value }}
                                    @elseif ($aiModel->accuracy !== null)
                                        {{ $aiModel->accuracy }}%
                                    @else
                                        Not available
                                    @endif
                                </td>
                                <td>
                                    @if ($evaluations->isNotEmpty())
                                        <div class="d-flex flex-column gap-1">
                                            @foreach ($evaluations->take(6) as $evaluation)
                                                <div>
                                                    <strong>{{ str_replace('_', ' ', ucfirst($evaluation->metric_name)) }}:</strong>
                                                    {{ $evaluation->display_value }}
                                                    <small class="text-muted">
                                                        {{ $evaluation->date?->format('M d, Y') }}
                                                    </small>
                                                </div>
                                            @endforeach
                                        </div>
                                    @else
                                        <span class="text-muted">No evaluation recorded</span>
                                    @endif
                                </td>
                                <td>
                                    @php($isActive = ($health['status'] ?? $aiModel->status) === 'active')
                                    <span class="badge {{ $isActive ? 'bg-success' : 'bg-secondary' }}">
                                        {{ $isActive ? 'Active' : 'Inactive' }}
                                    </span>
                                </td>
                                <td>{{ $health['endpoint'] ?? 'Not mapped' }}</td>
                                <td>{{ $health['message'] ?? 'Not checked' }}</td>
                                <td>
                                    @if (! empty($health['last_checked_at']))
                                        {{ $health['last_checked_at']->format('M d, Y h:i A') }}
                                    @else
                                        Not checked
                                    @endif
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="9" class="text-center text-muted">No AI models found.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <div class="page-heading">
        <div><h2>AI Models</h2><p>Monitor model versions, readiness, and current status.</p></div>
        <a href="{{ route('admin.ai-models.create') }}" class="primary-action">Add AI Model</a>
    </div>
    <article class="panel">
        <form method="GET" action="{{ route('admin.ai-models.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search model name, type, version...">
            <select name="model_type">
                <option value="">All model types</option>
                @foreach ($modelTypes as $type)
                    <option value="{{ $type }}" @selected(request('model_type') === $type)>{{ $type }}</option>
                @endforeach
            </select>
            <select name="status">
                <option value="">All statuses</option>
                @foreach ($statuses as $status)
                    <option value="{{ $status }}" @selected(request('status') === $status)>{{ $status }}</option>
                @endforeach
            </select>
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.ai-models.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($aiModels->isEmpty())
            <div class="empty-card">No AI models match the current filters.</div>
        @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>Model Name</th><th>Type</th><th>Version</th><th>Accuracy</th><th>Status</th><th>Actions</th></tr></thead>
                <tbody>
                    @foreach ($aiModels as $model)
                        <tr>
                            <td>{{ $model->model_name }}</td>
                            <td>{{ $model->model_type }}</td>
                            <td>{{ $model->version ?? 'N/A' }}</td>
                            <td>@include('admin.partials.confidence-bar', ['value' => $model->accuracy])</td>
                            <td>@include('admin.partials.status-badge', ['status' => $model->status])</td>
                            <td>
                                <div class="action-row">
                                    <a href="{{ route('admin.ai-models.show', $model) }}" class="icon-button">View</a>
                                    <a href="{{ route('admin.ai-models.edit', $model) }}" class="icon-button">Edit</a>
                                    <form method="POST" action="{{ route('admin.ai-models.destroy', $model) }}" class="inline-delete" onsubmit="return confirm('Are you sure you want to delete this AI model record?')">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="icon-button danger">Delete</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        <div class="pagination-wrap">{{ $aiModels->links() }}</div>
        @endif
    </article>
@endsection
