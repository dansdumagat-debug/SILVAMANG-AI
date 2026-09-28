@php
    $confidenceValue = $value !== null ? max(0, min(100, (float) $value)) : null;
    $confidenceTone = match (true) {
        $confidenceValue === null => null,
        $confidenceValue >= 80 => 'high',
        $confidenceValue >= 60 => 'medium',
        default => 'low',
    };
    $confidenceLabel = isset($label) && is_string($label) && trim($label) !== ''
        ? trim($label)
        : 'Confidence';
@endphp

@if ($confidenceValue !== null)
    <div class="confidence-meter confidence-{{ $confidenceTone }}" title="{{ $confidenceLabel }}: {{ number_format($confidenceValue, 2) }}%">
        <span class="confidence-value">{{ number_format($confidenceValue, 2) }}%</span>
        <div
            class="confidence-track"
            role="progressbar"
            aria-label="{{ $confidenceLabel }}"
            aria-valuemin="0"
            aria-valuemax="100"
            aria-valuenow="{{ number_format($confidenceValue, 2, '.', '') }}"
            aria-valuetext="{{ number_format($confidenceValue, 2) }} percent"
        >
            <div class="confidence-fill" style="width: {{ $confidenceValue }}%" aria-hidden="true"></div>
        </div>
    </div>
@else
    <span class="muted-text">N/A</span>
@endif
