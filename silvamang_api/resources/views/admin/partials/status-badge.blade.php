@php
    $normalizedStatus = strtolower((string) $status);
@endphp

<span class="status-badge status-{{ str_replace('_', '-', $normalizedStatus) }}">
    {{ $status ?: 'N/A' }}
</span>
