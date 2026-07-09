@extends('admin.layouts.app')

@section('title', 'Alert Details')

@section('content')
    <div class="page-heading">
        <div><h2>{{ $alert->title }}</h2><p>Alert and monitoring detail.</p></div>
        <a href="{{ route('admin.alerts.index') }}" class="secondary-action">Back</a>
    </div>

    <section class="review-grid">
        <article class="detail-card">
            <h3>Alert Summary</h3>
            <div class="detail-grid two">
                <div><span>Alert Type</span><strong>{{ $alert->alert_type }}</strong></div>
                <div><span>Severity</span><strong><span class="severity-badge severity-{{ strtolower($alert->severity) }}">{{ $alert->severity }}</span></strong></div>
                <div><span>Status</span><strong>@include('admin.partials.status-badge', ['status' => $alert->status])</strong></div>
                <div><span>Related Scan</span><strong>{{ $alert->relatedScanRecord?->record_code ?? 'N/A' }}</strong></div>
                <div><span>Created At</span><strong>{{ $alert->created_at?->format('M d, Y h:i A') }}</strong></div>
                <div><span>Updated At</span><strong>{{ $alert->updated_at?->format('M d, Y h:i A') }}</strong></div>
            </div>
            <div class="metadata-section"><span>Message</span><p>{{ $alert->message ?? 'N/A' }}</p></div>
        </article>

        <article class="detail-card">
            <h3>Update Status</h3>
            <form method="POST" action="{{ route('admin.alerts.update-status', $alert) }}" class="status-update-form">
                @csrf
                @method('PATCH')
                <label class="form-group">
                    Status
                    <select name="status" required>
                        @foreach (['open', 'reviewed', 'resolved', 'dismissed'] as $status)
                            <option value="{{ $status }}" @selected(old('status', $alert->status) === $status)>{{ ucfirst($status) }}</option>
                        @endforeach
                    </select>
                </label>
                <button type="submit" class="primary-action">Update Status</button>
            </form>

            @if ($alert->relatedScanRecord)
                <a href="{{ route('admin.scan-records.show', $alert->relatedScanRecord) }}" class="secondary-action">View Related Scan Record</a>
            @endif
        </article>
    </section>
@endsection
