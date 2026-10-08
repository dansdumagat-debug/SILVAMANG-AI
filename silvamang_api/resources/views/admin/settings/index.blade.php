@extends('admin.layouts.app')

@section('title', 'Settings')

@section('content')
    <div class="page-heading"><div><h2>Settings</h2><p>Read-only configuration and service checks. Checked {{ $checkedAt }}. Refresh to check again.</p></div></div>
    @php
        $badgeClass = fn ($status) => in_array($status, ['Connected', 'Ready', 'Available', 'Running'], true) ? 'completed' : 'pending';
    @endphp
    <section class="settings-grid">
        <article class="settings-card">
            <h3>System Information</h3>
            @foreach ($systemInfo as $label => $value)
                <div class="system-info-row"><span>{{ $label }}</span><strong>{{ $value }}</strong></div>
            @endforeach
        </article>

        <article class="settings-card">
            <h3>Database Status</h3>
            <div class="system-info-row"><span>Connection</span><strong>{{ $databaseInfo['Connection'] }}</strong></div>
            <div class="system-info-row"><span>Database</span><strong>{{ $databaseInfo['Database Name'] }}</strong></div>
            <div class="system-info-row"><span>Status</span><strong><span class="build-badge status-{{ $databaseInfo['Status'] }}">{{ ucfirst($databaseInfo['Status']) }}</span></strong></div>
            @if ($databaseInfo['Error'])
                <div class="metadata-section"><span>Error</span><p>{{ $databaseInfo['Error'] }}</p></div>
            @endif
        </article>

        <article class="settings-card">
            <h3>Storage Configuration</h3>
            @foreach ($storageInfo as $label => $value)
                <div class="system-info-row"><span>{{ $label }}</span><strong>{{ $value }}</strong></div>
            @endforeach
        </article>

        <article class="settings-card">
            <h3>API Configuration</h3>
            <div class="system-info-row"><span>Health Endpoint</span><strong>/api/health</strong></div>
            <div class="api-list">
                @foreach ($apiGroups as $endpoint)
                    <span>{{ $endpoint }}</span>
                @endforeach
            </div>
        </article>

        <article class="settings-card">
            <h3>AI Configuration</h3>
            @foreach ($aiConfiguration as $label => $status)
                <div class="system-info-row"><span>{{ $label }}</span><strong><span class="build-badge status-{{ $badgeClass($status) }}">{{ $status }}</span></strong></div>
            @endforeach
        </article>

        <article class="settings-card">
            <h3>Mobile Offline/Online Readiness</h3>
            <p>These features are implemented. This page cannot inspect unsynced records stored on a phone.</p>
            @foreach ($mobileReadiness as $label => $status)
                <div class="system-info-row"><span>{{ $label }}</span><strong>{{ $status }}</strong></div>
            @endforeach
        </article>

        <article class="settings-card full-width-card">
            <h3>Deployment Checks</h3>
            <p>Readiness checks do not replace testing a photo upload or identification. <a href="{{ url('/download') }}">Open Android download</a>. Review approved-photo training progress in Dataset Verification.</p>
            <div class="build-status-grid">
                @foreach ($buildStatus as $label => $status)
                    <div class="system-info-row"><span>{{ $label }}</span><strong><span class="build-badge status-{{ $badgeClass($status) }}">{{ $status }}</span></strong></div>
                @endforeach
            </div>
        </article>
    </section>
@endsection
