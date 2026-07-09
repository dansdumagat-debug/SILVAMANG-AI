@extends('admin.layouts.app')

@section('title', 'Measurement Details')

@section('content')
    <div class="page-heading">
        <div><h2>Measurement Details</h2><p>Review height and canopy measurement data.</p></div>
        <div class="action-row">
            @if ($measurement->scanRecord)
                <a href="{{ route('admin.scan-records.show', $measurement->scanRecord) }}" class="primary-action">View Scan Record</a>
            @endif
            <a href="{{ route('admin.measurements.index') }}" class="secondary-action">Back</a>
        </div>
    </div>

    <article class="detail-card">
        <div class="detail-grid">
            <div><span>Record Code</span><strong>{{ $measurement->scanRecord?->record_code ?? 'N/A' }}</strong></div>
            <div><span>Species</span><strong>{{ $measurement->scanRecord?->species?->scientific_name ?? 'N/A' }}</strong></div>
            <div><span>User</span><strong>{{ $measurement->scanRecord?->user?->name ?? 'N/A' }}</strong></div>
            <div><span>Height</span><strong>{{ $measurement->height_m ?? 'N/A' }} m</strong></div>
            <div><span>Canopy Width</span><strong>{{ $measurement->canopy_width_m ?? 'N/A' }} m</strong></div>
            <div><span>DBH</span><strong>{{ $measurement->dbh_cm ?? 'N/A' }} cm</strong></div>
            <div><span>Method</span><strong>{{ $measurement->measurement_method }}</strong></div>
            <div><span>Confidence</span>@include('admin.partials.confidence-bar', ['value' => $measurement->confidence])</div>
            <div><span>Measured At</span><strong>{{ $measurement->measured_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
            <div><span>Created At</span><strong>{{ $measurement->created_at?->format('M d, Y h:i A') }}</strong></div>
        </div>
        <div class="metadata-section"><span>Notes</span><p>{{ $measurement->notes ?? 'N/A' }}</p></div>
    </article>
@endsection
