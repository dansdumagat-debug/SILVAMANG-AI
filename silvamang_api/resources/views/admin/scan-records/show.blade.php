@extends('admin.layouts.app')

@section('title', 'Scan Record Details')

@section('content')
    <div class="page-heading">
        <div>
            <h2>{{ $scanRecord->record_code }}</h2>
            <p>Scan record review.</p>
        </div>
        <div class="action-row">
            @include('admin.partials.status-badge', ['status' => $scanRecord->identification_status])
            @include('admin.partials.status-badge', ['status' => $scanRecord->validation_status])
            <a href="{{ route('admin.scan-records.index') }}" class="secondary-action">Back</a>
        </div>
    </div>

    <section class="review-grid">
        <article class="detail-card">
            <h3>Identification Summary</h3>
            <div class="detail-grid two">
                <div><span>Top Scientific Name</span><strong>{{ $scanRecord->top_scientific_name ?? 'N/A' }}</strong></div>
                <div><span>Top Common Name</span><strong>{{ $scanRecord->top_common_name ?? 'N/A' }}</strong></div>
                <div><span>Confidence</span>@include('admin.partials.confidence-bar', ['value' => $scanRecord->confidence])</div>
                <div><span>Capture Mode</span><strong>{{ $scanRecord->capture_mode }}</strong></div>
                <div><span>Captured At</span><strong>{{ $scanRecord->captured_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
                <div><span>Synced At</span><strong>{{ $scanRecord->synced_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
            </div>
        </article>

        <article class="detail-card">
            <h3>User and Location</h3>
            <div class="detail-grid two">
                <div><span>User</span><strong>{{ $scanRecord->user ? $scanRecord->user->name . ' / ' . $scanRecord->user->email : 'N/A' }}</strong></div>
                <div><span>Location Name</span><strong>{{ $scanRecord->location_name ?? 'N/A' }}</strong></div>
                <div><span>Latitude</span><strong>{{ $scanRecord->latitude ?? 'N/A' }}</strong></div>
                <div><span>Longitude</span><strong>{{ $scanRecord->longitude ?? 'N/A' }}</strong></div>
                <div><span>Offline Reference</span><strong>{{ $scanRecord->offline_reference ?? 'N/A' }}</strong></div>
                <div><span>Address</span><strong>{{ $scanRecord->address ?? 'N/A' }}</strong></div>
            </div>
        </article>
    </section>

    <section class="review-grid">
        <article class="detail-card">
            <h3>Linked Species</h3>
            @if ($scanRecord->species)
                <div class="detail-grid two">
                    <div><span>Scientific Name</span><strong>{{ $scanRecord->species->scientific_name }}</strong></div>
                    <div><span>Common Name</span><strong>{{ $scanRecord->species->common_name ?? 'N/A' }}</strong></div>
                    <div><span>Family</span><strong>{{ $scanRecord->species->family ?? 'N/A' }}</strong></div>
                    <div><span>Conservation Status</span><strong>{{ $scanRecord->species->conservation_status ?? 'N/A' }}</strong></div>
                </div>
            @else
                <div class="empty-card">No linked species.</div>
            @endif
        </article>

        <article class="detail-card">
            <h3>Measurement</h3>
            @if ($scanRecord->measurement)
                <div class="detail-grid two">
                    <div><span>Height</span><strong>{{ $scanRecord->measurement->height_m ?? 'N/A' }} m</strong></div>
                    <div><span>Canopy Width</span><strong>{{ $scanRecord->measurement->canopy_width_m ?? 'N/A' }} m</strong></div>
                    <div><span>DBH</span><strong>{{ $scanRecord->measurement->dbh_cm ?? 'N/A' }} cm</strong></div>
                    <div><span>Method</span><strong>{{ $scanRecord->measurement->measurement_method }}</strong></div>
                    <div><span>Confidence</span>@include('admin.partials.confidence-bar', ['value' => $scanRecord->measurement->confidence])</div>
                    <div><span>Measured At</span><strong>{{ $scanRecord->measurement->measured_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
                </div>
            @else
                <div class="empty-card">No measurement record.</div>
            @endif
        </article>
    </section>

    <article class="detail-card">
        <h3>Top-K Predictions</h3>
        @if ($scanRecord->predictions->isEmpty())
            <div class="empty-card">No predictions recorded.</div>
        @else
            <div class="prediction-list">
                @foreach ($scanRecord->predictions->sortBy('rank') as $prediction)
                    <div class="prediction-row">
                        <strong>#{{ $prediction->rank }} {{ $prediction->scientific_name }}</strong>
                        <span>{{ $prediction->common_name ?? 'N/A' }} / {{ $prediction->model_name ?? 'No model' }} {{ $prediction->model_version }}</span>
                        @include('admin.partials.confidence-bar', ['value' => $prediction->confidence])
                    </div>
                @endforeach
            </div>
        @endif
    </article>

    <section class="review-grid">
        <article class="detail-card">
            <h3>Location Validation</h3>
            @if ($scanRecord->locationValidation)
                <div class="detail-grid two">
                    <div><span>Result</span><strong>@include('admin.partials.status-badge', ['status' => $scanRecord->locationValidation->result])</strong></div>
                    <div><span>Species</span><strong>{{ $scanRecord->locationValidation->species?->scientific_name ?? $scanRecord->species?->scientific_name ?? 'N/A' }}</strong></div>
                    <div><span>Latitude</span><strong>{{ $scanRecord->locationValidation->latitude ?? 'N/A' }}</strong></div>
                    <div><span>Longitude</span><strong>{{ $scanRecord->locationValidation->longitude ?? 'N/A' }}</strong></div>
                    <div><span>Distance</span><strong>{{ $scanRecord->locationValidation->distance_to_known_distribution_km ?? 'N/A' }} km</strong></div>
                    <div><span>Validated At</span><strong>{{ $scanRecord->locationValidation->validated_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
                </div>
                <div class="metadata-section"><span>Message</span><p>{{ $scanRecord->locationValidation->message ?? 'N/A' }}</p></div>
            @else
                <div class="empty-card">No location validation result available.</div>
            @endif
        </article>

        <article class="detail-card">
            <h3>Captured Images</h3>
            @if ($scanRecord->images->isEmpty())
                <div class="empty-card">No uploaded images for this record.</div>
            @else
                <div class="image-list">
                    @foreach ($scanRecord->images as $image)
                        @php
                            $imageExists = $image->image_path && \Illuminate\Support\Facades\Storage::disk('public')->exists($image->image_path);
                            $imageUrl = $imageExists ? asset('storage/' . $image->image_path) : null;
                            $fileSize = $image->file_size ? number_format($image->file_size / 1024, 1) . ' KB' : 'Size N/A';
                            $dimensions = $image->width && $image->height ? $image->width . ' x ' . $image->height : 'Dimensions N/A';
                            $plantPart = $image->plant_part ? ucfirst(str_replace('_', ' ', $image->plant_part)) : 'Plant part N/A';
                        @endphp
                        <div class="image-card">
                            @if ($imageUrl)
                                <img src="{{ $imageUrl }}" alt="{{ $plantPart }} image preview" class="image-card-preview">
                            @else
                                <div class="image-card-placeholder">Preview unavailable</div>
                            @endif
                            <div class="image-card-meta">
                                <strong>{{ $plantPart }}</strong>
                                <span>{{ $image->original_filename ?? 'No original filename' }}</span>
                                <span>{{ $image->mime_type ?? 'MIME N/A' }} / {{ $fileSize }}</span>
                                <span>{{ $dimensions }}</span>
                                <span>{{ $image->image_path ?? 'No image path' }}</span>
                                <span>Uploaded {{ $image->created_at?->format('M d, Y h:i A') ?? 'N/A' }}</span>
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif
        </article>
    </section>

    <article class="detail-card">
        <h3>Assistant Logs</h3>
        @if ($scanRecord->assistantLogs->isEmpty())
            <div class="empty-card">No assistant logs for this scan.</div>
        @else
            @foreach ($scanRecord->assistantLogs as $log)
                <div class="log-box">
                    <strong>{{ $log->question ?? 'No question' }}</strong>
                    <p>{{ \Illuminate\Support\Str::limit($log->response ?? 'No response', 180) }}</p>
                    <span>{{ $log->intent ?? 'N/A' }} / {{ $log->source ?? 'N/A' }} / {{ $log->created_at?->format('M d, Y') }}</span>
                </div>
            @endforeach
        @endif
    </article>
@endsection
