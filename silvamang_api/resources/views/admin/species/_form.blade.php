@csrf

<div class="form-grid">
    <label class="form-group">
        Scientific Name
        <input type="text" name="scientific_name" value="{{ old('scientific_name', $species->scientific_name) }}" required>
    </label>
    <label class="form-group">
        Common Name
        <input type="text" name="common_name" value="{{ old('common_name', $species->common_name) }}">
    </label>
    <label class="form-group">
        Family
        <input type="text" name="family" value="{{ old('family', $species->family) }}">
    </label>
    <label class="form-group">
        Genus
        <input type="text" name="genus" value="{{ old('genus', $species->genus) }}">
    </label>
    <label class="form-group">
        Conservation Status
        <input type="text" name="conservation_status" value="{{ old('conservation_status', $species->conservation_status) }}">
    </label>
    <label class="form-group">
        Native Status
        <input type="text" name="native_status" value="{{ old('native_status', $species->native_status) }}">
    </label>
    <label class="form-group">
        Max Height (m)
        <input type="number" name="max_height_m" step="0.01" min="0" value="{{ old('max_height_m', $species->max_height_m) }}">
    </label>
    <label class="form-group">
        Status
        <select name="status" required>
            @foreach (['active', 'inactive'] as $status)
                <option value="{{ $status }}" @selected(old('status', $species->status) === $status)>{{ ucfirst($status) }}</option>
            @endforeach
        </select>
    </label>
    <label class="form-group full">
        Description
        <textarea name="description" rows="4">{{ old('description', $species->description) }}</textarea>
    </label>
    <label class="form-group full">
        Habitat
        <textarea name="habitat" rows="3">{{ old('habitat', $species->habitat) }}</textarea>
    </label>
    <label class="form-group full">
        Distribution Notes
        <textarea name="distribution_notes" rows="3">{{ old('distribution_notes', $species->distribution_notes) }}</textarea>
    </label>
    <label class="form-group full">
        Ecological Role
        <textarea name="ecological_role" rows="3">{{ old('ecological_role', $species->ecological_role) }}</textarea>
    </label>
    <label class="form-group full">
        Identification Notes
        <textarea name="identification_notes" rows="3">{{ old('identification_notes', $species->identification_notes) }}</textarea>
    </label>
</div>

<div class="form-actions">
    <button type="submit" class="primary-action">{{ $submitLabel }}</button>
    <a href="{{ route('admin.species.index') }}" class="secondary-action">Cancel</a>
</div>
