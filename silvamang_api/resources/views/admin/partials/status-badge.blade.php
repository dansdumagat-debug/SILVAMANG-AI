@php
    $normalizedStatus = strtolower((string) $status);
    $statusLabel = $status ? ucwords(str_replace('_', ' ', (string) $status)) : 'N/A';
@endphp

<span class="status-badge status-{{ str_replace('_', '-', $normalizedStatus) }}">
    {{ $statusLabel }}
</span>
