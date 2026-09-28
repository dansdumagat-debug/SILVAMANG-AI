@php
    $rawStatus = trim((string) ($status ?? ''));
    $normalizedStatus = str_replace([' ', '-'], '_', strtolower($rawStatus));
    $statusSlug = trim((string) preg_replace('/[^a-z0-9]+/', '-', strtolower($rawStatus)), '-');
    $statusSlug = $statusSlug !== '' ? $statusSlug : 'not-available';
    $statusLabel = $rawStatus !== ''
        ? ucwords(str_replace(['_', '-'], ' ', $rawStatus))
        : 'N/A';

    $successStatuses = [
        'active', 'approved', 'available', 'closed', 'completed', 'connected',
        'healthy', 'linked', 'match', 'online', 'passed', 'ready', 'research',
        'resolved', 'synced', 'verified',
    ];
    $warningStatuses = [
        'awaiting_review', 'missing', 'needs_id', 'open', 'pending', 'pending_sync',
        'planned', 'processing', 'queued', 'unverified',
    ];
    $dangerStatuses = [
        'blocked', 'critical', 'error', 'failed', 'invalid', 'mismatch', 'offline',
        'reject', 'rejected',
    ];
    $infoStatuses = [
        'exported', 'in_progress', 'likely_found', 'processed', 'reviewed', 'running',
    ];

    $statusTone = match (true) {
        in_array($normalizedStatus, $successStatuses, true) => 'success',
        in_array($normalizedStatus, $warningStatuses, true) => 'warning',
        in_array($normalizedStatus, $dangerStatuses, true) => 'danger',
        in_array($normalizedStatus, $infoStatuses, true) => 'info',
        default => 'neutral',
    };
@endphp

<span class="status-badge status-tone-{{ $statusTone }} status-{{ $statusSlug }}">
    {{ $statusLabel }}
</span>
