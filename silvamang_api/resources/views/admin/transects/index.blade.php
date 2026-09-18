@extends('admin.layouts.app')

@section('title', $canViewAll ? 'Digital Transects' : 'My Digital Transects')

@push('styles')
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
@endpush

@section('content')
    <div class="page-heading">
        <div>
            <h2>{{ $canViewAll ? 'Digital Transects' : 'My Digital Transects' }}</h2>
            <p>GPS-based survey paths, field observations, and ecological monitoring summaries.</p>
        </div>
        <div style="display:flex; gap:8px; align-items:center; flex-wrap:wrap">
            <form method="GET" action="{{ route('admin.transects.export-excel') }}" style="display:flex; gap:8px; align-items:center; flex-wrap:wrap">
                @foreach(request()->except('plot_area_m2') as $key => $value)
                    @if(is_scalar($value))
                        <input type="hidden" name="{{ $key }}" value="{{ $value }}">
                    @endif
                @endforeach
                <label for="plot-area-m2">Plot area (m²)</label>
                <input id="plot-area-m2" type="number" name="plot_area_m2" min="0.01" step="any" value="{{ request('plot_area_m2') }}" placeholder="Optional" style="width:100px" title="Enter the sampled plot area for density and per-hectare formulas">
                <button type="submit" class="primary-action">Export Excel</button>
            </form>
            <a href="{{ route('admin.transects.export', request()->query()) }}" class="secondary-action">Export CSV</a>
            <small>Excel uses linked scans. Enter plot area for density and per-hectare formulas.</small>
        </div>
    </div>

    <section class="stats-grid transect-stats">
        @include('admin.partials.stat-card', ['label' => 'Transects', 'value' => $transects->count(), 'hint' => 'Matching survey records', 'icon' => 'TR'])
        @include('admin.partials.stat-card', ['label' => 'Completed', 'value' => $completedCount, 'hint' => 'Finished field paths', 'icon' => 'OK'])
        @include('admin.partials.stat-card', ['label' => 'Total Distance', 'value' => number_format($totalDistanceM, 1) . ' m', 'hint' => 'Combined mapped length', 'icon' => 'M'])
        @include('admin.partials.stat-card', ['label' => 'Observations', 'value' => $totalObservations, 'hint' => 'Linked scan records', 'icon' => 'OBS'])
    </section>

    <article class="panel transect-map-panel">
        <div class="panel-header transect-panel-header">
            <div>
                <h3>Transect Map</h3>
                <p>Lines connect each segment's recorded start and end. Green is GPS; blue is manual.</p>
            </div>
            <div class="transect-map-legend" aria-label="Map legend">
                <span><i class="legend-line gps"></i>GPS</span>
                <span><i class="legend-line manual"></i>Manual</span>
                <span><i class="legend-dot observation"></i>Observation</span>
            </div>
        </div>
        <div id="transect-map" class="transect-map-canvas" aria-label="Mapped digital transects"></div>
        @if ($mapTransects->isEmpty())
            <div class="transect-map-empty">No transect paths match the current filters.</div>
        @endif
    </article>

    <article class="panel">
        <form method="GET" action="{{ route('admin.transects.index') }}" class="filter-toolbar transect-filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search ID, name, or location">
            <select name="mode">
                <option value="">All modes</option>
                <option value="gps_tracking" @selected(request('mode') === 'gps_tracking')>GPS Tracking</option>
                <option value="manual_points" @selected(request('mode') === 'manual_points')>Manual Points</option>
            </select>
            <select name="status">
                <option value="">All statuses</option>
                <option value="completed" @selected(request('status') === 'completed')>Completed</option>
                <option value="draft" @selected(request('status') === 'draft')>Draft</option>
            </select>
            @if ($canViewAll)
                <select name="user_id">
                    <option value="">All researchers</option>
                    @foreach ($userOptions as $user)
                        <option value="{{ $user->id }}" @selected((string) request('user_id') === (string) $user->id)>
                            {{ $user->name }} / {{ $user->email }}
                        </option>
                    @endforeach
                </select>
            @endif
            <input type="date" name="date_from" value="{{ request('date_from') }}" aria-label="Date from">
            <input type="date" name="date_to" value="{{ request('date_to') }}" aria-label="Date to">
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.transects.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($transects->isEmpty())
            <div class="empty-card">No digital transects match the current filters.</div>
        @else
            <div class="table-wrap">
                <table class="transect-table">
                    <thead>
                        <tr>
                            <th>Transect</th>
                            <th>Date</th>
                            @if ($canViewAll)<th>Researcher</th>@endif
                            <th>Location</th>
                            <th>Mode</th>
                            <th>Distance</th>
                            <th>Direction</th>
                            <th>Points</th>
                            <th>Observations</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($transects as $transect)
                            @php
                                $observedAt = $transect->recorded_at ?? $transect->created_at;
                                $directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
                                $direction = $transect->bearing_degrees !== null
                                    ? $directions[((int) round(((float) $transect->bearing_degrees) / 45)) % 8]
                                    : 'N/A';
                            @endphp
                            <tr>
                                <td>
                                    <strong>{{ $transect->transect_code }}</strong>
                                    <span class="table-subtext">{{ $transect->transect_name }}</span>
                                </td>
                                <td>{{ $observedAt?->format('M d, Y') ?? 'N/A' }}</td>
                                @if ($canViewAll)
                                    <td>
                                        <strong>{{ $transect->user?->name ?? 'N/A' }}</strong>
                                        <span class="table-subtext">{{ $transect->user?->email ?? 'No email' }}</span>
                                    </td>
                                @endif
                                <td>{{ $transect->location_name ?? 'N/A' }}</td>
                                <td>{{ $transect->mode === 'gps_tracking' ? 'GPS Tracking' : 'Manual Points' }}</td>
                                <td>{{ number_format((float) $transect->total_distance_m, 1) }} m</td>
                                <td>{{ $direction }}{{ $transect->bearing_degrees !== null ? ' / ' . number_format((float) $transect->bearing_degrees, 1) . ' deg' : '' }}</td>
                                <td>{{ $transect->points_count }}</td>
                                <td>{{ $transect->observations_count }}</td>
                                <td>@include('admin.partials.status-badge', ['status' => $transect->status])</td>
                                <td><a href="{{ route('admin.transects.show', $transect) }}" class="icon-button">View Details</a></td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </article>

    <p class="transect-disclaimer">
        Digital transects provide GPS-based distance estimation and ecological documentation support. They do not replace validated scientific field protocols or calibrated survey equipment.
    </p>
@endsection

@push('scripts')
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script>
        const transects = @json($mapTransects);
        const defaultCenter = [10.3347, 125.0750];
        const map = L.map('transect-map', { preferCanvas: true, maxZoom: 24, zoomSnap: 0.5, zoomDelta: 0.5 }).setView(defaultCenter, 9);

        const streetLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 24,
            maxNativeZoom: 19,
            attribution: '&copy; OpenStreetMap contributors',
        }).addTo(map);
        const satelliteLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
            maxZoom: 24,
            maxNativeZoom: 19,
            attribution: 'Tiles &copy; Esri, Earthstar Geographics, and the GIS User Community',
        });
        L.control.layers({ Street: streetLayer, Satellite: satelliteLayer }).addTo(map);

        const allCoordinates = [];
        const escapeHtml = (value) => String(value ?? '')
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#039;');

        const endpointIcon = (label, color) => L.divIcon({
            className: 'transect-endpoint-icon',
            html: `<span style="--marker-color:${color}">${label}</span>`,
            iconSize: [30, 30],
            iconAnchor: [15, 15],
        });

        transects.forEach((transect) => {
            const coordinates = transect.points.map((point) => [point.latitude, point.longitude]);
            if (coordinates.length < 2) return;

            const color = transect.mode === 'gps_tracking' ? '#2F7D46' : '#2472B8';
            const popup = `
                <strong>${escapeHtml(transect.code)}: ${escapeHtml(transect.name)}</strong><br>
                ${escapeHtml(transect.location || 'Location not provided')}<br>
                ${Number(transect.distance_m).toFixed(1)} m / ${transect.points.length} GPS points<br>
                ${transect.observations.length} linked observations<br>
                <a href="${escapeHtml(transect.detail_url)}">Open details</a>
            `;

            const segments = transect.segments.length ? transect.segments : [[transect.points[0], transect.points[transect.points.length - 1]]];
            segments.forEach((segment, index) => {
                const start = [segment[0].latitude, segment[0].longitude];
                const end = [segment[1].latitude, segment[1].longitude];
                allCoordinates.push(start, end);
                L.polyline([start, end], { color: '#FFFFFF', weight: 11, opacity: 0.98 }).addTo(map);
                L.polyline([start, end], { color, weight: 7, opacity: 1 })
                    .addTo(map)
                    .bindPopup(popup);
                L.marker([(start[0] + end[0]) / 2, (start[1] + end[1]) / 2], {
                    icon: endpointIcon(escapeHtml(transect.map_label.slice(1)), color),
                }).addTo(map).bindTooltip(`${transect.map_label} line`);
                L.marker(start, { icon: endpointIcon('S', '#2F7D46') })
                    .addTo(map)
                    .bindTooltip(`${transect.map_label} segment ${index + 1} start`);
                L.marker(end, { icon: endpointIcon('E', '#C53A3A') })
                    .addTo(map)
                    .bindTooltip(`${transect.map_label} segment ${index + 1} end`);
            });

            transect.observations.forEach((observation) => {
                const coordinate = [observation.latitude, observation.longitude];
                allCoordinates.push(coordinate);
                L.circleMarker(coordinate, {
                    radius: 7,
                    color: '#FFFFFF',
                    weight: 2,
                    fillColor: '#F3B61F',
                    fillOpacity: 1,
                }).addTo(map).bindPopup(`
                    <strong>${escapeHtml(observation.record_code)}</strong><br>
                    <em>${escapeHtml(observation.species)}</em><br>
                    Linked to ${escapeHtml(transect.code)}
                `);
            });
        });

        if (allCoordinates.length > 0) {
            map.fitBounds(allCoordinates, { padding: [42, 42], maxZoom: 20 });
        }
    </script>
@endpush
