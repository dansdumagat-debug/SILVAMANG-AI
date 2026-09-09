@csrf

@php
    $lineValue = fn (string $field) => old($field, implode("\n", $education->{$field} ?? []));
@endphp

<div class="form-grid">
    <label class="form-group">
        Species
        <select name="species_id" required>
            <option value="">Select species</option>
            @foreach ($speciesList as $species)
                <option value="{{ $species->id }}" @selected((string) old('species_id', $education->species_id) === (string) $species->id)>
                    {{ $species->scientific_name }}{{ $species->common_name ? ' - ' . $species->common_name : '' }}
                </option>
            @endforeach
        </select>
    </label>
    <label class="form-group">
        Status
        <select name="status" required>
            @foreach ($statuses as $status)
                <option value="{{ $status }}" @selected(old('status', $education->status ?? 'active') === $status)>{{ ucfirst($status) }}</option>
            @endforeach
        </select>
    </label>
    <label class="form-group full">
        Species Overview
        <textarea name="overview" rows="5">{{ old('overview', $education->overview) }}</textarea>
    </label>
    <label class="form-group full">
        Physical Characteristics
        <textarea name="physical_characteristics" rows="5" placeholder="One characteristic per line">{{ $lineValue('physical_characteristics') }}</textarea>
    </label>
    <label class="form-group full">
        Leaf Characteristics
        <textarea name="leaf_characteristics" rows="4">{{ old('leaf_characteristics', $education->leaf_characteristics) }}</textarea>
    </label>
    <label class="form-group full">
        Root Characteristics
        <textarea name="root_characteristics" rows="4">{{ old('root_characteristics', $education->root_characteristics) }}</textarea>
    </label>
    <label class="form-group full">
        Habitat
        <textarea name="habitat" rows="4" placeholder="One habitat per line">{{ $lineValue('habitat') }}</textarea>
    </label>
    <label class="form-group full">
        Geographic Distribution
        <textarea name="distribution" rows="4" placeholder="One location or region per line">{{ $lineValue('distribution') }}</textarea>
    </label>
    <label class="form-group full">
        Ecological Importance
        <textarea name="ecological_importance" rows="5" placeholder="One ecological role per line">{{ $lineValue('ecological_importance') }}</textarea>
    </label>
    <label class="form-group full">
        Mangrove History
        <textarea name="history" rows="5">{{ old('history', $education->history) }}</textarea>
    </label>
    <label class="form-group full">
        Discovery and Scientific Study
        <textarea name="scientific_study" rows="5">{{ old('scientific_study', $education->scientific_study) }}</textarea>
    </label>
    <label class="form-group full">
        Conservation and Protection
        <textarea name="conservation_information" rows="5" placeholder="One conservation point per line">{{ $lineValue('conservation_information') }}</textarea>
    </label>
    <label class="form-group full">
        Interesting Facts
        <textarea name="interesting_facts" rows="5" placeholder="One fact per line">{{ $lineValue('interesting_facts') }}</textarea>
    </label>
    <label class="form-group full">
        References
        <textarea name="references" rows="4" placeholder="One source per line">{{ $lineValue('references') }}</textarea>
    </label>
</div>

<div class="form-actions">
    <button type="submit" class="primary-action">{{ $submitLabel }}</button>
    <a href="{{ route('admin.mangrove-education.index') }}" class="secondary-action">Cancel</a>
</div>
