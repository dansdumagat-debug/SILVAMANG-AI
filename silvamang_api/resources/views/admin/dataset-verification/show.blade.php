@extends('admin.layouts.app')

@section('title', 'Dataset Image Review')

@section('content')
    @php
        $fileSize = $scanImage->file_size ? number_format($scanImage->file_size / 1024, 1) . ' KB' : 'N/A';
        $dimensions = $scanImage->width && $scanImage->height ? $scanImage->width . ' x ' . $scanImage->height : 'N/A';
        $uploadedPlantPart = $scanImage->plant_part ? ucfirst(str_replace('_', ' ', $scanImage->plant_part)) : 'N/A';
    @endphp

    <div class="page-heading">
        <div>
            <h2>Dataset Image Review</h2>
            <p>{{ $scanImage->original_filename ?? 'Uploaded scan image' }}</p>
        </div>
        <div class="action-row">
            @include('admin.partials.status-badge', ['status' => $scanImage->dataset_status ?? 'pending'])
            <a href="{{ route('admin.dataset-verification.index') }}" class="secondary-action">Back</a>
        </div>
    </div>

    <section class="dataset-review-layout">
        <article class="detail-card">
            <h3>Image Preview</h3>
            @if ($imageUrl)
                <img src="{{ $imageUrl }}" alt="Scan image preview" class="dataset-large-preview">
            @else
                <div class="dataset-large-placeholder">Preview unavailable</div>
            @endif
        </article>

        <article class="detail-card">
            <h3>Existing Metadata</h3>
            <div class="detail-grid two">
                <div><span>Scan Record Code</span><strong>{{ $scanImage->scanRecord?->record_code ?? 'N/A' }}</strong></div>
                <div><span>Uploaded Plant Part</span><strong>{{ $uploadedPlantPart }}</strong></div>
                <div><span>Original Filename</span><strong>{{ $scanImage->original_filename ?? 'N/A' }}</strong></div>
                <div><span>MIME Type</span><strong>{{ $scanImage->mime_type ?? 'N/A' }}</strong></div>
                <div><span>File Size</span><strong>{{ $fileSize }}</strong></div>
                <div><span>Image Dimensions</span><strong>{{ $dimensions }}</strong></div>
                <div><span>Uploaded At</span><strong>{{ $scanImage->created_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
                <div><span>Linked Species</span><strong>{{ $scanImage->scanRecord?->species?->scientific_name ?? 'N/A' }}</strong></div>
                <div><span>Dataset Status</span><strong>@include('admin.partials.status-badge', ['status' => $scanImage->dataset_status ?? 'pending'])</strong></div>
                <div><span>Exported At</span><strong>{{ $scanImage->dataset_exported_at?->format('M d, Y h:i A') ?? 'N/A' }}</strong></div>
            </div>
            @if ($scanImage->dataset_status === 'exported')
                <div class="export-path-box">
                    <span>Dataset Export Path</span>
                    <strong>{{ $scanImage->dataset_export_path ?? 'N/A' }}</strong>
                </div>
                <div class="export-note">If metadata is changed after export, re-export support will be handled in a later phase.</div>
            @endif
        </article>
    </section>

    <article class="detail-card verification-form-card">
        <h3>Verification Form</h3>
        <form method="POST" action="{{ route('admin.dataset-verification.update', $scanImage) }}" class="admin-form-grid">
            @csrf
            @method('PATCH')

            <label>
                <span>Verified Species</span>
                <select name="verified_species_id">
                    <option value="">Select species</option>
                    @foreach ($speciesOptions as $species)
                        <option value="{{ $species->id }}" @selected((string) old('verified_species_id', $scanImage->verified_species_id) === (string) $species->id)>
                            {{ $species->scientific_name }}{{ $species->common_name ? ' - ' . $species->common_name : '' }}
                        </option>
                    @endforeach
                </select>
            </label>

            <label>
                <span>Verified Plant Part</span>
                <select name="verified_plant_part">
                    <option value="">Select plant part</option>
                    @foreach ($plantParts as $plantPart)
                        <option value="{{ $plantPart }}" @selected(old('verified_plant_part', $scanImage->verified_plant_part) === $plantPart)>{{ ucfirst(str_replace('_', ' ', $plantPart)) }}</option>
                    @endforeach
                </select>
            </label>

            <label>
                <span>Dataset Status</span>
                <select name="dataset_status" required>
                    @foreach ($datasetStatuses as $status)
                        <option value="{{ $status }}" @selected(old('dataset_status', $scanImage->dataset_status ?? 'pending') === $status)>{{ ucfirst($status) }}</option>
                    @endforeach
                </select>
            </label>

            <label>
                <span>Image Quality</span>
                <select name="image_quality">
                    <option value="">Select quality</option>
                    @foreach ($imageQualities as $quality)
                        <option value="{{ $quality }}" @selected(old('image_quality', $scanImage->image_quality) === $quality)>{{ ucfirst($quality) }}</option>
                    @endforeach
                </select>
            </label>

            <label class="form-wide">
                <span>Dataset Notes</span>
                <textarea name="dataset_notes" rows="4" placeholder="Add notes for future model training review.">{{ old('dataset_notes', $scanImage->dataset_notes) }}</textarea>
            </label>

            <label class="form-wide">
                <span>Rejection Reason</span>
                <textarea name="rejection_reason" rows="4" placeholder="Required only when rejecting an image.">{{ old('rejection_reason', $scanImage->rejection_reason) }}</textarea>
            </label>

            <div class="form-actions form-wide">
                <button type="submit" class="primary-action">Save Verification</button>
                <a href="{{ route('admin.dataset-verification.index') }}" class="secondary-action">Back</a>
            </div>
        </form>
    </article>
@endsection
