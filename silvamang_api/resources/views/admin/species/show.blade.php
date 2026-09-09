@extends('admin.layouts.app')

@section('title', 'Species Details')

@section('content')
    <div class="page-heading">
        <div><h2>{{ $species->scientific_name }}</h2><p>Species detail record.</p></div>
        <div class="action-row">
            <a href="{{ route('admin.species.edit', $species) }}" class="primary-action">Edit Species</a>
            <a href="{{ route('admin.species.index') }}" class="secondary-action">Back</a>
        </div>
    </div>

    <article class="detail-card">
        <div class="detail-grid">
            <div><span>Scientific Name</span><strong>{{ $species->scientific_name }}</strong></div>
            <div><span>Common Name</span><strong>{{ $species->common_name ?? 'N/A' }}</strong></div>
            <div><span>Family</span><strong>{{ $species->family ?? 'N/A' }}</strong></div>
            <div><span>Genus</span><strong>{{ $species->genus ?? 'N/A' }}</strong></div>
            <div><span>Habitat</span><strong>{{ $species->habitat ?? 'N/A' }}</strong></div>
            <div><span>Conservation Status</span><strong>{{ $species->conservation_status ?? 'N/A' }}</strong></div>
            <div><span>Native Status</span><strong>{{ $species->native_status ?? 'N/A' }}</strong></div>
            <div><span>Max Height</span><strong>{{ $species->max_height_m ? $species->max_height_m . ' m' : 'N/A' }}</strong></div>
            <div><span>Status</span><strong>@include('admin.partials.status-badge', ['status' => $species->status])</strong></div>
        </div>
        <div class="metadata-section"><span>Description</span><p>{{ $species->description ?? 'N/A' }}</p></div>
        <div class="metadata-section"><span>Distribution Notes</span><p>{{ $species->distribution_notes ?? 'N/A' }}</p></div>
        <div class="metadata-section"><span>Ecological Role</span><p>{{ $species->ecological_role ?? 'N/A' }}</p></div>
        <div class="metadata-section"><span>Identification Notes</span><p>{{ $species->identification_notes ?? 'N/A' }}</p></div>
    </article>

    <article class="detail-card">
        <div class="panel-header">
            <div>
                <h3>External Biodiversity References</h3>
                <span>Cached iNaturalist observations used only as supporting species context.</span>
            </div>
            @if (auth()->user()?->hasAnyRole(['super_admin', 'admin']))
                <a href="{{ route('admin.external-biodiversity.index', ['species_id' => $species->id]) }}" class="secondary-action">Manage References</a>
            @endif
        </div>

        @if ($species->externalObservations->isEmpty())
            <div class="empty-card">No cached external biodiversity references for this species yet.</div>
        @else
            <div class="image-list">
                @foreach ($species->externalObservations as $observation)
                    <div class="image-card">
                        @if ($observation->photo_url)
                            <img src="{{ $observation->photo_url }}" alt="iNaturalist observation photo" class="image-card-preview">
                        @else
                            <div class="image-card-placeholder">No photo</div>
                        @endif
                        <div class="image-card-meta">
                            <strong>{{ $observation->location ?? 'Location not provided' }}</strong>
                            <span>Observer: {{ $observation->observer ?? 'N/A' }}</span>
                            <span>Observed: {{ $observation->observed_date?->format('M d, Y') ?? 'N/A' }}</span>
                            <span>Quality: {{ ucfirst(str_replace('_', ' ', $observation->quality_grade ?? 'unknown')) }}</span>
                            <a href="https://www.inaturalist.org/observations/{{ $observation->source_observation_id }}" target="_blank" rel="noopener" class="icon-button">Open iNaturalist</a>
                        </div>
                    </div>
                @endforeach
            </div>
        @endif
    </article>
@endsection
