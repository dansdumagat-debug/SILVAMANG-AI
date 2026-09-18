@php
    $currentUser = auth()->user();
    $adminConsoleRoles = ['super_admin', 'admin', 'researcher'];
    $isMobileUserOnly = $currentUser?->hasRole('mobile_user') && ! $currentUser?->hasAnyRole($adminConsoleRoles);
    $primaryLinks = [
        ['label' => 'Dashboard', 'route' => 'admin.dashboard', 'match' => 'admin.dashboard'],
        ['label' => 'My Map', 'route' => 'admin.my-map', 'match' => 'admin.my-map', 'mobile_only' => true],
        ['label' => 'Digital Transects', 'route' => 'admin.transects.index', 'match' => 'admin.transects.*'],
        ['label' => 'Reports & Analytics', 'route' => 'admin.reports.index', 'match' => 'admin.reports.*', 'roles' => $adminConsoleRoles],
    ];
    $groups = [
        'Fieldwork' => [
            ['label' => 'Mangrove Scans', 'route' => 'admin.scan-monitoring.index', 'match' => 'admin.scan-*', 'roles' => $adminConsoleRoles],
            ['label' => 'Measurements', 'route' => 'admin.measurements.index', 'match' => 'admin.measurements.*', 'roles' => $adminConsoleRoles],
            ['label' => 'Location Validation', 'route' => 'admin.location-validations.index', 'match' => 'admin.location-validations.*', 'roles' => $adminConsoleRoles],
            ['label' => 'Observation Map', 'route' => 'admin.observation-map.index', 'match' => 'admin.observation-map.*', 'roles' => $adminConsoleRoles],
            ['label' => 'Dataset Verification', 'route' => 'admin.dataset-verification.index', 'match' => 'admin.dataset-verification.*', 'roles' => $adminConsoleRoles],
        ],
        'Species & Learning' => [
            ['label' => 'Species Management', 'route' => 'admin.species.index', 'match' => 'admin.species.*', 'roles' => $adminConsoleRoles],
            ['label' => 'Mangrove Knowledge', 'route' => 'admin.mangrove-knowledge.index', 'match' => 'admin.mangrove-knowledge.*', 'roles' => ['super_admin', 'admin']],
            ['label' => 'Educational Content', 'route' => 'admin.mangrove-education.index', 'match' => 'admin.mangrove-education.*', 'roles' => ['super_admin', 'admin']],
            ['label' => 'External Biodiversity Data', 'route' => 'admin.external-biodiversity.index', 'match' => 'admin.external-biodiversity.*', 'roles' => ['super_admin', 'admin']],
        ],
        'AI & System' => [
            ['label' => 'Chatbot Management', 'route' => 'admin.chatbot-management.index', 'match' => 'admin.chatbot-management.*', 'roles' => ['super_admin', 'admin']],
            ['label' => 'AI Assistant Logs', 'route' => 'admin.assistant-logs.index', 'match' => 'admin.assistant-logs.*', 'roles' => $adminConsoleRoles],
            ['label' => 'AI Models', 'route' => 'admin.ai-models.index', 'match' => 'admin.ai-models.*', 'roles' => $adminConsoleRoles],
            ['label' => 'Alerts & Monitoring', 'route' => 'admin.alerts.index', 'match' => 'admin.alerts.*', 'roles' => $adminConsoleRoles],
            ['label' => 'Users', 'route' => 'admin.users.index', 'match' => 'admin.users.*', 'roles' => ['super_admin', 'admin']],
        ],
    ];
    $utilityLinks = [
        ['label' => 'Settings', 'route' => 'admin.settings.index', 'match' => 'admin.settings.*'],
    ];
    $canSeeLink = fn ($link) => ! (($link['mobile_only'] ?? false) && ! $isMobileUserOnly)
        && (! isset($link['roles']) || $currentUser?->hasAnyRole($link['roles']));
@endphp

<aside class="admin-sidebar" id="admin-sidebar" aria-label="Admin navigation">
    <div class="brand-block">
        <div class="brand-mark">
            <span class="leaf-mark"></span>
        </div>
        <div>
            <h1>SILVAMANG AI</h1>
            <p>{{ $isMobileUserOnly ? 'Field Dashboard' : 'Admin Console' }}</p>
        </div>
    </div>

    <nav class="sidebar-nav">
        @foreach ($primaryLinks as $link)
            @continue(! $canSeeLink($link))
            <a href="{{ route($link['route']) }}" class="{{ request()->routeIs($link['match']) ? 'active' : '' }}" @if(request()->routeIs($link['match'])) aria-current="page" @endif>{{ $link['label'] }}</a>
        @endforeach

        @foreach ($groups as $groupLabel => $groupLinks)
            @php
                $visibleLinks = array_values(array_filter($groupLinks, $canSeeLink));
                $groupActive = collect($visibleLinks)->contains(fn ($link) => request()->routeIs($link['match']));
            @endphp
            @if (count($visibleLinks))
                <details class="sidebar-group" @if($groupActive) open @endif>
                    <summary class="{{ $groupActive ? 'group-active' : '' }}">{{ $groupLabel }}<span class="sidebar-chevron" aria-hidden="true"></span></summary>
                    <div class="sidebar-group-links">
                        @foreach ($visibleLinks as $link)
                            <a href="{{ route($link['route']) }}" class="{{ request()->routeIs($link['match']) ? 'active' : '' }}" @if(request()->routeIs($link['match'])) aria-current="page" @endif>{{ $link['label'] }}</a>
                        @endforeach
                    </div>
                </details>
            @endif
        @endforeach

        @foreach ($utilityLinks as $link)
            <a href="{{ route($link['route']) }}" class="{{ request()->routeIs($link['match']) ? 'active' : '' }}" @if(request()->routeIs($link['match'])) aria-current="page" @endif>{{ $link['label'] }}</a>
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
