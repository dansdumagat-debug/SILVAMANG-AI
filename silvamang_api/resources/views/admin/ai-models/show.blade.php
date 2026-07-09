@extends('admin.layouts.app')

@section('title', 'AI Model Details')

@section('content')
    <div class="page-heading">
        <div><h2>{{ $aiModel->model_name }}</h2><p>AI model detail record.</p></div>
        <div class="action-row">
            <a href="{{ route('admin.ai-models.edit', $aiModel) }}" class="primary-action">Edit AI Model</a>
            <a href="{{ route('admin.ai-models.index') }}" class="secondary-action">Back</a>
        </div>
    </div>

    <article class="detail-card">
        <div class="detail-grid">
            <div><span>Model Name</span><strong>{{ $aiModel->model_name }}</strong></div>
            <div><span>Model Type</span><strong>{{ $aiModel->model_type }}</strong></div>
            <div><span>Version</span><strong>{{ $aiModel->version ?? 'N/A' }}</strong></div>
            <div><span>Accuracy</span><strong>{{ $aiModel->accuracy ? $aiModel->accuracy . '%' : 'N/A' }}</strong></div>
            <div><span>Precision</span><strong>{{ $aiModel->precision_score ? $aiModel->precision_score . '%' : 'N/A' }}</strong></div>
            <div><span>Recall</span><strong>{{ $aiModel->recall_score ? $aiModel->recall_score . '%' : 'N/A' }}</strong></div>
            <div><span>F1 Score</span><strong>{{ $aiModel->f1_score ? $aiModel->f1_score . '%' : 'N/A' }}</strong></div>
            <div><span>Top-k Accuracy</span><strong>{{ $aiModel->top_k_accuracy ? $aiModel->top_k_accuracy . '%' : 'N/A' }}</strong></div>
            <div><span>Status</span><strong>@include('admin.partials.status-badge', ['status' => $aiModel->status])</strong></div>
            <div><span>Deployed At</span><strong>{{ $aiModel->deployed_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
        </div>
        <div class="metadata-section"><span>Notes</span><p>{{ $aiModel->notes ?? 'N/A' }}</p></div>
    </article>
@endsection
