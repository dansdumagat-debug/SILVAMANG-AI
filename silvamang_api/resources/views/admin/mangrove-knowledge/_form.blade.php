@csrf

<div class="form-grid">
    <label class="form-group">
        Category
        <select name="category" required>
            @foreach ($categories as $category)
                <option value="{{ $category }}" @selected(old('category', $knowledge->category) === $category)>
                    {{ str_replace('_', ' ', ucfirst($category)) }}
                </option>
            @endforeach
        </select>
    </label>
    <label class="form-group">
        Species Name
        <input type="text" name="species_name" value="{{ old('species_name', $knowledge->species_name) }}" placeholder="Optional scientific name">
    </label>
    <label class="form-group">
        Status
        <select name="status">
            @foreach ($statuses as $status)
                <option value="{{ $status }}" @selected(old('status', $knowledge->status ?? 'active') === $status)>
                    {{ ucfirst($status) }}
                </option>
            @endforeach
        </select>
    </label>
    <label class="form-group full">
        Question
        <textarea name="question" rows="3" required>{{ old('question', $knowledge->question) }}</textarea>
    </label>
    <label class="form-group full">
        Verified Answer
        <textarea name="answer" rows="8" required>{{ old('answer', $knowledge->answer) }}</textarea>
    </label>
    <label class="form-group full">
        Keywords
        <input type="text" name="keywords" value="{{ old('keywords', $knowledge->keywords) }}" placeholder="Comma-separated search words">
    </label>
    <label class="form-group full">
        Related Species
        <input type="text" name="related_species" value="{{ old('related_species', $knowledge->related_species) }}" placeholder="Comma-separated scientific names">
    </label>
    <label class="form-group full">
        Reference / Source
        <input type="text" name="reference_source" value="{{ old('reference_source', $knowledge->reference_source) }}" placeholder="Book, field guide, DENR material, research paper, or local verified source">
    </label>
</div>

<div class="form-actions">
    <button type="submit" class="primary-action">{{ $submitLabel }}</button>
    <a href="{{ route('admin.mangrove-knowledge.index') }}" class="secondary-action">Cancel</a>
</div>
