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
            ['label' => 'Alerts & Monitoring', 'route' => 'admin.alerts.index', 'match' => 'admin.alerts.*', 'roles' => $adminConsoleRoles],
            ['label' => 'Users', 'route' => 'admin.users.index', 'match' => 'admin.users.*', 'roles' => ['super_admin', 'admin']],
        ],
    ];
    $utilityLinks = [
        ['label' => 'Settings', 'route' => 'admin.settings.index', 'match' => 'admin.settings.*', 'roles' => ['super_admin', 'admin']],
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
            <h1>{{ $adminPreferences['console_name'] }}</h1>
            <p>Mangroves for a Greener Tomorrow</p>
        </div>
    </div>

    <nav class="sidebar-nav">
        @foreach ($primaryLinks as $link)
            @continue(! $canSeeLink($link))
            <a href="{{ route($link['route']) }}" class="{{ request()->routeIs($link['match']) ? 'active' : '' }}" @if(request()->routeIs($link['match'])) aria-current="page" @endif>@include('admin.partials.sidebar-icon', ['label' => $link['label']])<span>{{ $link['label'] }}</span></a>
        @endforeach

        @foreach ($groups as $groupLabel => $groupLinks)
            @php
                $visibleLinks = array_values(array_filter($groupLinks, $canSeeLink));
                $groupActive = collect($visibleLinks)->contains(fn ($link) => request()->routeIs($link['match']));
            @endphp
            @if (count($visibleLinks))
                <details class="sidebar-group" @if($groupActive) open @endif>
                    <summary class="{{ $groupActive ? 'group-active' : '' }}">@include('admin.partials.sidebar-icon', ['label' => $groupLabel])<span class="sidebar-group-label">{{ $groupLabel }}</span><span class="sidebar-chevron" aria-hidden="true"></span></summary>
                    <div class="sidebar-group-links">
                        @foreach ($visibleLinks as $link)
                            <a href="{{ route($link['route']) }}" class="{{ request()->routeIs($link['match']) ? 'active' : '' }}" @if(request()->routeIs($link['match'])) aria-current="page" @endif>{{ $link['label'] }}</a>
                        @endforeach
                    </div>
                </details>
            @endif
        @endforeach

        @foreach ($utilityLinks as $link)
            @continue(! $canSeeLink($link))
            <a href="{{ route($link['route']) }}" class="{{ request()->routeIs($link['match']) ? 'active' : '' }}" @if(request()->routeIs($link['match'])) aria-current="page" @endif>@include('admin.partials.sidebar-icon', ['label' => $link['label']])<span>{{ $link['label'] }}</span></a>
        @endforeach
    </nav>

    <div class="sidebar-card sidebar-mangrove-card">
        <img src="{{ asset('images/sidebar-mangroves.png') }}" alt="" width="1672" height="941" decoding="async">
        <strong>&ldquo;Healthy<br>Mangroves<br>Stronger<br>Communities&rdquo;</strong>
        <span class="sidebar-card-leaf leaf-mark" aria-hidden="true"></span>
    </div>
</aside>
