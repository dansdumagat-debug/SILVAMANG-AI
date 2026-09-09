@php
    $currentUser = auth()->user();
    $adminConsoleRoles = ['super_admin', 'admin', 'researcher'];
    $links = [
        ['label' => 'Dashboard', 'route' => 'admin.dashboard', 'match' => 'admin.dashboard'],
        ['label' => 'Species Management', 'route' => 'admin.species.index', 'match' => 'admin.species.*', 'roles' => $adminConsoleRoles],
        ['label' => 'Mangrove Scan Monitoring', 'route' => 'admin.scan-monitoring.index', 'match' => 'admin.scan-*', 'roles' => $adminConsoleRoles],
        ['label' => 'Dataset Verification', 'route' => 'admin.dataset-verification.index', 'match' => 'admin.dataset-verification.*', 'roles' => $adminConsoleRoles],
        ['label' => 'Measurements', 'route' => 'admin.measurements.index', 'match' => 'admin.measurements.*', 'roles' => $adminConsoleRoles],
        ['label' => 'Location Validation', 'route' => 'admin.location-validations.index', 'match' => 'admin.location-validations.*', 'roles' => $adminConsoleRoles],
        ['label' => 'Observation Map', 'route' => 'admin.observation-map.index', 'match' => 'admin.observation-map.*', 'roles' => $adminConsoleRoles],
        ['label' => 'Chatbot Management', 'route' => 'admin.chatbot-management.index', 'match' => 'admin.chatbot-management.*', 'roles' => ['super_admin', 'admin']],
        ['label' => 'AI Assistant Logs', 'route' => 'admin.assistant-logs.index', 'match' => 'admin.assistant-logs.*', 'roles' => $adminConsoleRoles],
        ['label' => 'Mangrove Knowledge', 'route' => 'admin.mangrove-knowledge.index', 'match' => 'admin.mangrove-knowledge.*', 'roles' => ['super_admin', 'admin']],
        ['label' => 'Educational Content', 'route' => 'admin.mangrove-education.index', 'match' => 'admin.mangrove-education.*', 'roles' => ['super_admin', 'admin']],
        ['label' => 'External Biodiversity Data', 'route' => 'admin.external-biodiversity.index', 'match' => 'admin.external-biodiversity.*', 'roles' => ['super_admin', 'admin']],
        ['label' => 'Alerts & Monitoring', 'route' => 'admin.alerts.index', 'match' => 'admin.alerts.*', 'roles' => $adminConsoleRoles],
        ['label' => 'Reports & Analytics', 'route' => 'admin.reports.index', 'match' => 'admin.reports.*', 'roles' => $adminConsoleRoles],
        ['label' => 'AI Models', 'route' => 'admin.ai-models.index', 'match' => 'admin.ai-models.*', 'roles' => $adminConsoleRoles],
        ['label' => 'Users', 'route' => 'admin.users.index', 'match' => 'admin.users.*', 'roles' => ['super_admin', 'admin']],
        ['label' => 'Settings', 'route' => 'admin.settings.index', 'match' => 'admin.settings.*'],
    ];
@endphp

<aside class="admin-sidebar" id="admin-sidebar" aria-label="Admin navigation">
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
