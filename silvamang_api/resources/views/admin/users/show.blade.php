@extends('admin.layouts.app')

@section('title', 'User Details')

@section('content')
    <div class="page-heading">
        <div><h2>{{ $user->name }}</h2><p>User account review and activity summary.</p></div>
        <div class="action-row">
            <a href="{{ route('admin.users.edit', $user) }}" class="primary-action">Edit</a>
            <a href="{{ route('admin.users.index') }}" class="secondary-action">Back</a>
        </div>
    </div>

    <article class="detail-card">
        <div class="detail-grid">
            <div><span>Name</span><strong>{{ $user->name }}</strong></div>
            <div><span>Email</span><strong>{{ $user->email }}</strong></div>
            <div><span>Email Verified At</span><strong>{{ $user->email_verified_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
            <div><span>Created At</span><strong>{{ $user->created_at?->format('M d, Y h:i A') }}</strong></div>
            <div><span>Updated At</span><strong>{{ $user->updated_at?->format('M d, Y h:i A') }}</strong></div>
            <div><span>Roles</span><strong>{{ $user->roles->pluck('display_name')->join(', ') ?: 'N/A' }}</strong></div>
            <div><span>Scan Records</span><strong>{{ $user->scan_records_count }}</strong></div>
            <div><span>Assistant Logs</span><strong>{{ $user->assistant_logs_count }}</strong></div>
        </div>
    </article>

    <section class="review-grid">
        <article class="detail-card">
            <h3>Latest Scan Records</h3>
            @forelse ($latestScanRecords as $record)
                <div class="model-row">
                    <div><strong>{{ $record->record_code }}</strong><span>{{ $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Pending' }}</span></div>
                    <a href="{{ route('admin.scan-records.show', $record) }}" class="icon-button">View</a>
                </div>
            @empty
                <div class="empty-card">No scan records for this user.</div>
            @endforelse
        </article>

        <article class="detail-card">
            <h3>Latest Assistant Logs</h3>
            @forelse ($latestAssistantLogs as $log)
                <div class="log-box">
                    <strong>{{ \Illuminate\Support\Str::limit($log->question ?? 'No question', 70) }}</strong>
                    <span>{{ $log->created_at?->format('M d, Y') }}</span>
                </div>
            @empty
                <div class="empty-card">No assistant logs for this user.</div>
            @endforelse
        </article>
    </section>
@endsection
