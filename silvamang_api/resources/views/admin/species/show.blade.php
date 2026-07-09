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
@endsection
