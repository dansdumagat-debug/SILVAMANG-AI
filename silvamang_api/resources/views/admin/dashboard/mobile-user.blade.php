@php
    $pinPositions = [
        [12, 24],
        [32, 48],
        [58, 28],
        [76, 57],
        [23, 70],
        [46, 62],
        [68, 42],
        [84, 28],
    ];
@endphp

<div class="page-heading">
    <div>
        <h2>My Field Dashboard</h2>
        <p>Welcome back, {{ $mobileUser->name }}. Your observations, map pins, measurements, and field story are gathered here.</p>
    </div>
    <div class="date-chip">{{ now()->format('M d, Y') }}</div>
</div>

<section class="stats-grid">
    @include('admin.partials.stat-card', ['label' => 'My Scans', 'value' => $personalStats['total_scans'], 'hint' => 'Records you submitted', 'icon' => 'ME'])
    @include('admin.partials.stat-card', ['label' => 'Map Pins', 'value' => $personalStats['map_pins'], 'hint' => 'GPS-tagged records', 'icon' => 'PIN'])
    @include('admin.partials.stat-card', ['label' => 'Species Found', 'value' => $personalStats['species_found'], 'hint' => 'Unique identifications', 'icon' => 'SP'])
    @include('admin.partials.stat-card', ['label' => 'Measurements', 'value' => $personalStats['measurements'], 'hint' => 'Height or width logs', 'icon' => 'HT'])
    @include('admin.partials.stat-card', ['label' => 'Matched Sites', 'value' => $personalStats['validation_matches'], 'hint' => 'Validated locations', 'icon' => 'OK'])
    @include('admin.partials.stat-card', ['label' => 'Pending Sync', 'value' => $personalStats['pending_sync'], 'hint' => 'Offline records waiting', 'icon' => 'SYNC'])
</section>

<section class="dashboard-grid mobile-field-grid">
    <article class="panel mobile-map-panel">
        <div class="panel-header">
            <h3>My Map Pins</h3>
            <a href="{{ route('admin.my-map') }}" class="reset-link">Open map</a>
        </div>
        @if ($mapPins->isEmpty())
            <div class="empty-card">No GPS pins yet.</div>
        @else
            <div class="mobile-map-canvas" aria-label="Personal map pin preview">
                @foreach ($mapPins as $record)
                    @php
                        $position = $pinPositions[$loop->index % count($pinPositions)];
                    @endphp
                    <span class="mobile-map-pin" style="left: {{ $position[0] }}%; top: {{ $position[1] }}%;" title="{{ $record->location_name ?? $record->barangay ?? 'Mapped record' }}"></span>
                @endforeach
            </div>
            <div class="pin-list">
                @foreach ($mapPins->take(4) as $record)
                    @php
                        $latitude = $record->latitude ?? $record->locationValidation?->latitude;
                        $longitude = $record->longitude ?? $record->locationValidation?->longitude;
                    @endphp
                    <div>
                        <strong>{{ $record->location_name ?? $record->barangay ?? 'Pinned record' }}</strong>
                        <span>{{ $latitude }}, {{ $longitude }}</span>
                    </div>
                @endforeach
            </div>
        @endif
    </article>

    <article class="panel mobile-story-panel">
        <div class="panel-header"><h3>My Field Story</h3><span>Latest activity</span></div>
        <div class="activity-list">
            @forelse ($latestScanRecords as $record)
                @php
                    $observedAt = $record->captured_at ?? $record->created_at;
                    $speciesName = $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Pending identification';
                    $location = $record->barangay ?: $record->manual_barangay ?: $record->location_name ?: 'Location not set';
                @endphp
                <div class="mobile-story-row">
                    <span>{{ $observedAt?->format('M d') ?? 'N/A' }}</span>
                    <div>
                        <strong>{{ $speciesName }}</strong>
                        <small>{{ $location }} &middot; {{ ucfirst(str_replace('_', ' ', $record->validation_status ?? 'pending')) }}</small>
                    </div>
                </div>
            @empty
                <div class="empty-card">No field story yet.</div>
            @endforelse
        </div>
    </article>
</section>

<section class="dashboard-grid">
    <article class="panel report-card">
        <div class="panel-header"><h3>7-Day Scan Volume</h3><span>{{ $scanTrend->sum('count') }} scans</span></div>
        @include('admin.partials.mini-bar-chart', ['items' => $scanTrend])
    </article>

    <article class="panel report-card">
        <div class="panel-header"><h3>My Top Species</h3><span>Top 5</span></div>
        @forelse ($topIdentifiedSpecies as $species)
            @include('admin.partials.progress-bar', ['label' => $species->name, 'value' => $species->total, 'max' => max(1, $topIdentifiedSpecies->max('total')), 'suffix' => ' scans'])
        @empty
            <div class="empty-card">No species identification data yet.</div>
        @endforelse
    </article>
</section>

<section class="dashboard-grid">
    <article class="panel wide">
        <div class="panel-header"><h3>My Recent Records</h3><span>Latest 6</span></div>
        @if ($latestScanRecords->isEmpty())
            <div class="empty-card">No records yet.</div>
        @else
            <div class="table-wrap">
                <table class="compact-table report-table">
                    <thead><tr><th>Record</th><th>Species</th><th>Location</th><th>Measurement</th><th>Validation</th><th>Date</th></tr></thead>
                    <tbody>
                        @foreach ($latestScanRecords as $record)
                            @php
                                $observedAt = $record->captured_at ?? $record->created_at;
                                $speciesName = $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Pending';
                                $location = $record->barangay ?: $record->manual_barangay ?: $record->location_name ?: $record->address;
                                $height = $record->measurement?->height_m ?? $record->height_m;
                                $width = $record->measurement?->canopy_width_m ?? $record->canopy_width_m;
                            @endphp
                            <tr>
                                <td><strong>{{ $record->record_code }}</strong></td>
                                <td>{{ $speciesName }}</td>
                                <td>{{ $location ?? 'N/A' }}</td>
                                <td>
                                    <span class="table-subtext">H: {{ $height ? $height . ' m' : 'N/A' }}</span>
                                    <span class="table-subtext">W: {{ $width ? $width . ' m' : 'N/A' }}</span>
                                </td>
                                <td>@include('admin.partials.status-badge', ['status' => $record->validation_status])</td>
                                <td>{{ $observedAt?->format('M d, Y') ?? 'N/A' }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </article>
</section>
