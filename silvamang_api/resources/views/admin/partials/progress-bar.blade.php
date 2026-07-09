@php
    $progressValue = (float) ($value ?? 0);
    $progressMax = max(1, (float) ($max ?? 100));
    $progressPercent = max(0, min(100, ($progressValue / $progressMax) * 100));
@endphp

<div class="progress-metric">
    <div class="progress-meta">
        <span>{{ $label }}</span>
        <strong>{{ rtrim(rtrim(number_format($progressValue, 2), '0'), '.') }}{{ $suffix ?? '' }}</strong>
    </div>
    <div class="progress-track">
        <div class="progress-fill" style="width: {{ $progressPercent }}%"></div>
    </div>
</div>
