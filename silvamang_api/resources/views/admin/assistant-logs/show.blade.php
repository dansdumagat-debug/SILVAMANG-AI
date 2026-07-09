@extends('admin.layouts.app')

@section('title', 'Assistant Log Details')

@section('content')
    <div class="page-heading">
        <div><h2>Assistant Log Details</h2><p>Review assistant conversation trace.</p></div>
        <div class="action-row">
            @if ($assistantLog->scanRecord)
                <a href="{{ route('admin.scan-records.show', $assistantLog->scanRecord) }}" class="primary-action">View Scan Record</a>
            @endif
            <a href="{{ route('admin.assistant-logs.index') }}" class="secondary-action">Back</a>
        </div>
    </div>

    <article class="detail-card">
        <div class="detail-grid">
            <div><span>User</span><strong>{{ $assistantLog->user ? $assistantLog->user->name . ' / ' . $assistantLog->user->email : 'N/A' }}</strong></div>
            <div><span>Linked Scan Record</span><strong>{{ $assistantLog->scanRecord?->record_code ?? 'N/A' }}</strong></div>
            <div><span>Species</span><strong>{{ $assistantLog->scanRecord?->species?->scientific_name ?? 'N/A' }}</strong></div>
            <div><span>Intent</span><strong>{{ $assistantLog->intent ?? 'N/A' }}</strong></div>
            <div><span>Source</span><strong>{{ $assistantLog->source ?? 'N/A' }}</strong></div>
            <div><span>Created At</span><strong>{{ $assistantLog->created_at?->format('M d, Y h:i A') }}</strong></div>
        </div>
        <div class="metadata-section"><span>Question</span><p>{{ $assistantLog->question ?? 'N/A' }}</p></div>
        <div class="metadata-section log-response"><span>Response</span><p>{{ $assistantLog->response ?? 'N/A' }}</p></div>
    </article>
@endsection
