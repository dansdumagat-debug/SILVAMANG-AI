@extends('admin.layouts.app')

@section('title', 'Location Validation Details')

@section('content')
    <div class="page-heading">
        <div><h2>Location Validation Details</h2><p>Review species-location validation data.</p></div>
        <div class="action-row">
            @if ($locationValidation->scanRecord)
                <a href="{{ route('admin.scan-records.show', $locationValidation->scanRecord) }}" class="primary-action">View Scan Record</a>
            @endif
            <a href="{{ route('admin.location-validations.index') }}" class="secondary-action">Back</a>
        </div>
    </div>

    <article class="detail-card">
        <div class="detail-grid">
            <div><span>Record Code</span><strong>{{ $locationValidation->scanRecord?->record_code ?? 'N/A' }}</strong></div>
            <div><span>User</span><strong>{{ $locationValidation->scanRecord?->user?->name ?? 'N/A' }}</strong></div>
            <div><span>Species</span><strong>{{ $locationValidation->species?->scientific_name ?? 'N/A' }}</strong></div>
            <div><span>Latitude</span><strong>{{ $locationValidation->latitude ?? 'N/A' }}</strong></div>
            <div><span>Longitude</span><strong>{{ $locationValidation->longitude ?? 'N/A' }}</strong></div>
            <div><span>Result</span><strong>@include('admin.partials.status-badge', ['status' => $locationValidation->result])</strong></div>
            <div><span>Distance</span><strong>{{ $locationValidation->distance_to_known_distribution_km ?? 'N/A' }} km</strong></div>
            <div><span>Validated At</span><strong>{{ $locationValidation->validated_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
            <div><span>Created At</span><strong>{{ $locationValidation->created_at?->format('M d, Y h:i A') }}</strong></div>
        </div>
        <div class="metadata-section"><span>Message</span><p>{{ $locationValidation->message ?? 'N/A' }}</p></div>
    </article>
@endsection
