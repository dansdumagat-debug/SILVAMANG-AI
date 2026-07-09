@php
    $currentUser = auth()->user();
    $links = [
        ['label' => 'Dashboard', 'route' => 'admin.dashboard', 'match' => 'admin.dashboard'],
        ['label' => 'Species Management', 'route' => 'admin.species.index', 'match' => 'admin.species.*'],
        ['label' => 'Scan Records', 'route' => 'admin.scan-records.index', 'match' => 'admin.scan-records.*'],
        ['label' => 'Measurements', 'route' => 'admin.measurements.index', 'match' => 'admin.measurements.*'],
        ['label' => 'Location Validation', 'route' => 'admin.location-validations.index', 'match' => 'admin.location-validations.*'],
        ['label' => 'AI Assistant Logs', 'route' => 'admin.assistant-logs.index', 'match' => 'admin.assistant-logs.*'],
        ['label' => 'Alerts & Monitoring', 'route' => 'admin.alerts.index', 'match' => 'admin.alerts.*'],
        ['label' => 'Reports & Analytics', 'route' => 'admin.reports.index', 'match' => 'admin.reports.*'],
        ['label' => 'AI Models', 'route' => 'admin.ai-models.index', 'match' => 'admin.ai-models.*'],
        ['label' => 'Users', 'route' => 'admin.users.index', 'match' => 'admin.users.*', 'roles' => ['super_admin', 'admin']],
        ['label' => 'Settings', 'route' => 'admin.settings.index', 'match' => 'admin.settings.*'],
    ];
@endphp

<aside class="admin-sidebar">
    <div class="brand-block">
        <div class="brand-mark">
            <span class="leaf-mark"></span>
        </div>
        <div>
            <h1>SILVAMANG AI</h1>
            <p>Admin Console</p>
        </div>
    </div>

    <nav class="sidebar-nav">
        @foreach ($links as $link)
            @continue(isset($link['roles']) && ! $currentUser?->hasAnyRole($link['roles']))
            @if ($link['route'])
                <a href="{{ route($link['route']) }}" class="{{ request()->routeIs($link['match']) ? 'active' : '' }}">
                    <span>{{ $link['label'] }}</span>
                </a>
            @else
                <span class="disabled-link">{{ $link['label'] }}</span>
            @endif
        @endforeach
    </nav>

    <div class="sidebar-card">
        <div class="sprout-visual">
            <span></span>
            <span></span>
        </div>
        <strong>Smart Technology</strong>
        <p>for Stronger Mangrove Ecosystems</p>
    </div>
</aside>
