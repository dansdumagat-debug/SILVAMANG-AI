@extends('admin.layouts.app')

@section('title', 'Dataset Verification')

@section('content')
<div class="dataset-verification-page">
    <div class="page-heading">
        <div>
            <h2>Dataset Verification</h2>
            <p>Review uploaded mangrove images before using them for AI training.</p>
        </div>
    </div>

    <article class="panel" style="margin-bottom:20px">
        <h3>Automatic species training</h3>
        <p>Approved leaves, bark, roots and flower photos are checked hourly. Training starts with at least 20 new unique photos, including 5 photos each from at least 2 species. New models require accuracy review before publication.</p>
        @php
            $trainingLabels = [
                'waiting_for_resources' => 'Waiting for server capacity',
                'waiting_for_baseline' => 'Preparing reference dataset',
                'waiting_for_approved_photos' => 'Waiting for more approved photos',
                'waiting_for_unique_approved_photos' => 'Waiting for more unique approved photos',
                'extracting_features' => 'Preparing training images',
                'training' => 'Training a candidate model',
                'candidate_ready_for_review' => 'Candidate ready for accuracy review',
                'no_improvement' => 'Candidate did not improve accuracy; current model retained',
                'source_changed_retry_required' => 'Approved photos changed; retry scheduled',
                'error' => 'Training needs attention; current model retained',
            ];
        @endphp
        <strong>{{ $trainingLabels[$trainingStatus['state'] ?? ''] ?? 'Worker not yet reporting' }}</strong>
        @if(isset($trainingStatus['approved']))
            <p>Eligible approved photos: {{ $trainingStatus['approved'] }}</p>
        @endif
        @if(isset($trainingStatus['report']['baseline']['accuracy']))
            <p>Current model validation accuracy: {{ number_format($trainingStatus['report']['baseline']['accuracy'] * 100, 2) }}%</p>
            @if(isset($trainingStatus['report']['candidate_metrics']['accuracy']))
                <p>Candidate validation accuracy: {{ number_format($trainingStatus['report']['candidate_metrics']['accuracy'] * 100, 2) }}%. Requires independent evaluation before publication.</p>
            @endif
        @endif
        @if($trainingStatus['previous_candidate_needs_review'] ?? false)
            <p>A previous candidate used photos whose approvals changed. Review it again before publication.</p>
        @endif
        @if(isset($trainingStatus['updated_at']))
            <p>Last check: {{ \Carbon\Carbon::parse($trainingStatus['updated_at'])->timezone('Asia/Manila')->format('M d, Y g:i A') }} PHT</p>
        @endif
    </article>

    <section class="dataset-export-panel">
        <article class="export-action-card">
            <div>
                <h3>Export Verified Images</h3>
                <p>Prepare verified images for future species identification and plant-part training.</p>
            </div>
            <form method="POST" action="{{ route('admin.dataset-verification.export') }}">
                @csrf
                <button type="submit" class="primary-action">Export Verified Images</button>
            </form>
        </article>

        <div class="dataset-count-grid">
            <div class="summary-tone-warning"><span>Pending</span><strong>{{ $pendingCount }}</strong></div>
            <div class="summary-tone-success"><span>Verified</span><strong>{{ $verifiedCount }}</strong></div>
            <div class="summary-tone-info"><span>Exported</span><strong>{{ $exportedCount }}</strong></div>
            <div class="summary-tone-danger"><span>Rejected</span><strong>{{ $rejectedCount }}</strong></div>
        </div>
    </section>

    <article class="panel">
        <form method="GET" action="{{ route('admin.dataset-verification.index') }}" class="filter-toolbar dataset-filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" aria-label="Search images" placeholder="Search filename, record, species...">
            <select name="dataset_status" aria-label="Dataset status">
                <option value="">All dataset status</option>
                @foreach ($datasetStatuses as $status)
                    <option value="{{ $status }}" @selected(request('dataset_status') === $status)>{{ ucfirst($status) }}</option>
                @endforeach
            </select>
            <select name="image_quality" aria-label="Image quality">
                <option value="">All image quality</option>
                @foreach ($imageQualities as $quality)
                    <option value="{{ $quality }}" @selected(request('image_quality') === $quality)>{{ ucfirst($quality) }}</option>
                @endforeach
            </select>
            <select name="verified_species_id" aria-label="Verified species">
                <option value="">All verified species</option>
                @foreach ($speciesOptions as $species)
                    <option value="{{ $species->id }}" @selected((string) request('verified_species_id') === (string) $species->id)>{{ $species->scientific_name }}</option>
                @endforeach
            </select>
            <select name="verified_plant_part" aria-label="Plant part">
                <option value="">All plant parts</option>
                @foreach ($plantParts as $plantPart)
                    <option value="{{ $plantPart }}" @selected(request('verified_plant_part') === $plantPart)>{{ ucfirst(str_replace('_', ' ', $plantPart)) }}</option>
                @endforeach
            </select>
            <div class="dataset-filter-actions">
                <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.dataset-verification.index') }}" class="reset-link">Reset</a>
            </div>
        </form>

        @if ($scanImages->isEmpty())
            <div class="empty-card">No uploaded scan images available for dataset verification.</div>
        @else
            <div class="dataset-card-grid">
                @foreach ($scanImages as $scanImage)
                    @php
                        $imageExists = $scanImage->image_path && \Illuminate\Support\Facades\Storage::disk('public')->exists($scanImage->image_path);
                        $imageUrl = $imageExists ? asset('storage/' . $scanImage->image_path) : null;
                        $uploadedPlantPart = $scanImage->plant_part ? ucfirst(str_replace('_', ' ', $scanImage->plant_part)) : 'N/A';
                        $verifiedPlantPart = $scanImage->verified_plant_part ? ucfirst(str_replace('_', ' ', $scanImage->verified_plant_part)) : 'Not verified';
                    @endphp
                    <article class="dataset-image-card">
                        @if ($imageUrl)
                            <img loading="lazy" src="{{ $imageUrl }}" alt="{{ $uploadedPlantPart }} preview">
                        @else
                            <div class="dataset-image-placeholder">Preview unavailable</div>
                        @endif
                        <div class="dataset-image-body">
                            <div class="dataset-card-head">
                                <strong>{{ $scanImage->original_filename ?? 'Unnamed image' }}</strong>
                                @include('admin.partials.status-badge', ['status' => $scanImage->dataset_status ?? 'pending'])
                            </div>
                            <div class="metadata-row"><span>Uploaded plant part</span><strong>{{ $uploadedPlantPart }}</strong></div>
                            <div class="metadata-row"><span>Verified plant part</span><strong>{{ $verifiedPlantPart }}</strong></div>
                            <div class="metadata-row"><span>Record</span><strong>{{ $scanImage->scanRecord?->record_code ?? 'N/A' }}</strong></div>
                            <div class="metadata-row"><span>{{ $scanImage->scanRecord?->suggested_species_source ?? 'App prediction' }}</span><strong>{{ $scanImage->scanRecord?->suggested_species_name ?? 'No prediction' }}</strong></div>
                            <div class="metadata-row"><span>Verified species</span><strong>{{ $scanImage->verifiedSpecies?->scientific_name ?? 'Not verified' }}</strong></div>
                            <div class="metadata-row"><span>Image quality</span><strong class="quality-badge quality-{{ $scanImage->image_quality ?? 'none' }}">{{ $scanImage->image_quality ?? 'N/A' }}</strong></div>
                            <a href="{{ route('admin.dataset-verification.show', $scanImage) }}" class="icon-button action-warning">View/Review</a>
                        </div>
                    </article>
                @endforeach
            </div>
            <div class="pagination-wrap">{{ $scanImages->links() }}</div>
        @endif
    </article>
</div>
@endsection
