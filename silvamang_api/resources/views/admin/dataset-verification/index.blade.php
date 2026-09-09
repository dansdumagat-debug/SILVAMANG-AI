@extends('admin.layouts.app')

@section('title', 'Dataset Verification')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Dataset Verification</h2>
            <p>Review uploaded mangrove images before using them for AI training.</p>
        </div>
    </div>

    <section class="dataset-export-panel">
        <article class="export-action-card">
            <div>
                <h3>Export Verified Images</h3>
                <p>Copy verified scan images into dataset/raw/ for future CNN and YOLO training.</p>
            </div>
            <form method="POST" action="{{ route('admin.dataset-verification.export') }}">
                @csrf
                <button type="submit" class="primary-action">Export Verified Images</button>
            </form>
        </article>

        <div class="dataset-count-grid">
            <div><span>Pending</span><strong>{{ $pendingCount }}</strong></div>
            <div><span>Verified</span><strong>{{ $verifiedCount }}</strong></div>
            <div><span>Exported</span><strong>{{ $exportedCount }}</strong></div>
            <div><span>Rejected</span><strong>{{ $rejectedCount }}</strong></div>
        </div>
    </section>

    <article class="panel">
        <form method="GET" action="{{ route('admin.dataset-verification.index') }}" class="filter-toolbar dataset-filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search filename, record, species...">
            <select name="dataset_status">
                <option value="">All dataset status</option>
                @foreach ($datasetStatuses as $status)
                    <option value="{{ $status }}" @selected(request('dataset_status') === $status)>{{ ucfirst($status) }}</option>
                @endforeach
            </select>
            <select name="image_quality">
                <option value="">All image quality</option>
                @foreach ($imageQualities as $quality)
                    <option value="{{ $quality }}" @selected(request('image_quality') === $quality)>{{ ucfirst($quality) }}</option>
                @endforeach
            </select>
            <select name="verified_species_id">
                <option value="">All verified species</option>
                @foreach ($speciesOptions as $species)
                    <option value="{{ $species->id }}" @selected((string) request('verified_species_id') === (string) $species->id)>{{ $species->scientific_name }}</option>
                @endforeach
            </select>
            <select name="verified_plant_part">
                <option value="">All plant parts</option>
                @foreach ($plantParts as $plantPart)
                    <option value="{{ $plantPart }}" @selected(request('verified_plant_part') === $plantPart)>{{ ucfirst(str_replace('_', ' ', $plantPart)) }}</option>
                @endforeach
            </select>
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.dataset-verification.index') }}" class="reset-link">Reset</a>
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
                            <img src="{{ $imageUrl }}" alt="{{ $uploadedPlantPart }} preview">
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
                            <div class="metadata-row"><span>Verified species</span><strong>{{ $scanImage->verifiedSpecies?->scientific_name ?? 'Not verified' }}</strong></div>
                            <div class="metadata-row"><span>Image quality</span><strong class="quality-badge quality-{{ $scanImage->image_quality ?? 'none' }}">{{ $scanImage->image_quality ?? 'N/A' }}</strong></div>
                            <a href="{{ route('admin.dataset-verification.show', $scanImage) }}" class="icon-button">View/Review</a>
                        </div>
                    </article>
                @endforeach
            </div>
            <div class="pagination-wrap">{{ $scanImages->links() }}</div>
        @endif
    </article>
@endsection
