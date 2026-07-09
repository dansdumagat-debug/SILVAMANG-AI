@csrf

<div class="form-grid">
    <label class="form-group">
        Model Name
        <input type="text" name="model_name" value="{{ old('model_name', $aiModel->model_name) }}" required>
    </label>
    <label class="form-group">
        Model Type
        <select name="model_type" required>
            @foreach (['classification', 'detection', 'segmentation', 'depth_estimation', 'assistant'] as $type)
                <option value="{{ $type }}" @selected(old('model_type', $aiModel->model_type) === $type)>{{ str_replace('_', ' ', ucfirst($type)) }}</option>
            @endforeach
        </select>
    </label>
    <label class="form-group">
        Version
        <input type="text" name="version" value="{{ old('version', $aiModel->version) }}">
    </label>
    <label class="form-group">
        Status
        <select name="status" required>
            @foreach (['active', 'inactive', 'training', 'archived'] as $status)
                <option value="{{ $status }}" @selected(old('status', $aiModel->status) === $status)>{{ ucfirst($status) }}</option>
            @endforeach
        </select>
    </label>
    <label class="form-group">
        Accuracy
        <input type="number" name="accuracy" step="0.01" min="0" max="100" value="{{ old('accuracy', $aiModel->accuracy) }}">
    </label>
    <label class="form-group">
        Precision
        <input type="number" name="precision_score" step="0.01" min="0" max="100" value="{{ old('precision_score', $aiModel->precision_score) }}">
    </label>
    <label class="form-group">
        Recall
        <input type="number" name="recall_score" step="0.01" min="0" max="100" value="{{ old('recall_score', $aiModel->recall_score) }}">
    </label>
    <label class="form-group">
        F1 Score
        <input type="number" name="f1_score" step="0.01" min="0" max="100" value="{{ old('f1_score', $aiModel->f1_score) }}">
    </label>
    <label class="form-group">
        Top-k Accuracy
        <input type="number" name="top_k_accuracy" step="0.01" min="0" max="100" value="{{ old('top_k_accuracy', $aiModel->top_k_accuracy) }}">
    </label>
    <label class="form-group">
        Deployed At
        <input type="datetime-local" name="deployed_at" value="{{ old('deployed_at', optional($aiModel->deployed_at)->format('Y-m-d\TH:i')) }}">
    </label>
    <label class="form-group full">
        Notes
        <textarea name="notes" rows="4">{{ old('notes', $aiModel->notes) }}</textarea>
    </label>
</div>

<div class="form-actions">
    <button type="submit" class="primary-action">{{ $submitLabel }}</button>
    <a href="{{ route('admin.ai-models.index') }}" class="secondary-action">Cancel</a>
</div>
