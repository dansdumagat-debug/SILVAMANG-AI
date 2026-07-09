@php
    $confidenceValue = $value !== null ? max(0, min(100, (float) $value)) : null;
@endphp

@if ($confidenceValue !== null)
    <div class="confidence-meter" title="{{ number_format($confidenceValue, 2) }}%">
        <span>{{ number_format($confidenceValue, 2) }}%</span>
        <div class="confidence-track">
            <div class="confidence-fill" style="width: {{ $confidenceValue }}%"></div>
        </div>
    </div>
@else
    <span class="muted-text">N/A</span>
@endif
