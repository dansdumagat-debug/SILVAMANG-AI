@extends('admin.layouts.app')

@section('title', $transect->transect_code)

@push('styles')
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
@endpush

@section('content')
    <section class="detail-card">
        <h3>Field Transect Number</h3>
        <p>Enter the recorded field number (for example 1, 2, or 4) used in the Excel workbook.</p>
        <form method="POST" action="{{ route('admin.transects.number', $transect) }}">
            @csrf @method('PATCH')
            <div class="admin-form-grid">
                <label>Transect number<input type="number" name="transect_number" min="1" max="1000000" required value="{{ old('transect_number', $transect->transect_number) }}"></label>
            </div>
            @error('transect_number')<p>{{ $message }}</p>@enderror
            <button class="primary-action" type="submit">Save Transect Number</button>
        </form>
    </section>

    @php
        $observedAt = $transect->recorded_at ?? $transect->created_at;
        $directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
        $direction = $transect->bearing_degrees !== null
            ? $directions[((int) round(((float) $transect->bearing_degrees) / 45)) % 8]
            : 'N/A';
    @endphp

    <div class="page-heading">
        <div>
            <h2>{{ $transect->transect_code }}: {{ $transect->transect_name }}</h2>
            <p>Mapped field path, linked mangrove observations, and ecological monitoring summary.</p>
        </div>
        <div class="action-row">
            @include('admin.partials.status-badge', ['status' => $transect->status])
            <a href="{{ route('admin.transects.export-excel', ['transect_id' => $transect->id]) }}" class="primary-action">Export Excel</a>
            <a href="{{ route('admin.transects.index') }}" class="neutral-action">Back</a>
        </div>
    </div>

    <section class="stats-grid transect-stats">
        @include('admin.partials.stat-card', ['label' => 'Start to end distance', 'value' => number_format((float) $transect->total_distance_m, 1) . ' m', 'hint' => 'Sum of each user’s straight-line segment', 'icon' => 'M'])
        @include('admin.partials.stat-card', ['label' => 'Direction', 'value' => $direction, 'hint' => $transect->bearing_degrees !== null ? number_format((float) $transect->bearing_degrees, 1) . ' degrees' : 'Bearing unavailable', 'icon' => 'DIR'])
        @include('admin.partials.stat-card', ['label' => 'GPS Points', 'value' => $transect->points->count(), 'hint' => 'Start, intermediate, and end', 'icon' => 'GPS'])
        @include('admin.partials.stat-card', ['label' => 'Observations', 'value' => $transect->observations->count(), 'hint' => 'Linked scan records', 'icon' => 'OBS'])
    </section>

    <article class="panel transect-map-panel">
        <div class="panel-header transect-panel-header">
            <div>
                <h3>Field Path</h3>
                <p>{{ $transect->mode === 'gps_tracking' ? 'GPS-tracked survey line' : 'Manually selected survey line' }}</p>
            </div>
            <div class="transect-map-legend" aria-label="Map legend">
                <span>
                    <i class="legend-line {{ $transect->mode === 'gps_tracking' ? 'gps' : 'manual' }}"></i>
                    {{ $transect->mode === 'gps_tracking' ? 'GPS path' : 'Manual path' }}
                </span>
                <span><i class="legend-dot start"></i>Start</span>
                <span><i class="legend-dot end"></i>End</span>
                <span><i class="legend-dot observation"></i>Observation</span>
            </div>
        </div>
        <div id="transect-detail-map" class="transect-map-canvas" aria-label="{{ $transect->transect_code }} map"></div>
    </article>

    <section class="review-grid">
        <article class="detail-card">
            <h3>Field Record</h3>
            <div class="detail-grid two">
                <div><span>Transect ID</span><strong>{{ $transect->transect_code }}</strong></div>
                <div><span>Researcher</span><strong>{{ $transect->user?->name ?? 'N/A' }}</strong></div>
                <div><span>Location</span><strong>{{ $transect->location_name ?? 'N/A' }}</strong></div>
                <div><span>Date Recorded</span><strong>{{ $observedAt?->format('F d, Y h:i A') ?? 'N/A' }}</strong></div>
                <div><span>Collection Mode</span><strong>{{ $transect->mode === 'gps_tracking' ? 'GPS Tracking' : 'Manual Points' }}</strong></div>
                <div><span>Average GPS Accuracy</span><strong>{{ $transect->gps_accuracy_m !== null ? number_format((float) $transect->gps_accuracy_m, 1) . ' m' : 'N/A' }}</strong></div>
                <div><span>Start Coordinates</span><strong>{{ $transect->start_latitude }}, {{ $transect->start_longitude }}</strong></div>
                <div><span>End Coordinates</span><strong>{{ $transect->end_latitude }}, {{ $transect->end_longitude }}</strong></div>
            </div>
            <div class="metadata-section"><span>Description</span><p>{{ $transect->description ?? 'No field description provided.' }}</p></div>
        </article>

        <article class="detail-card">
            <h3>Species Distribution</h3>
            @if ($speciesDistribution->isEmpty())
                <div class="empty-card compact-empty">No species observations are attached yet.</div>
            @else
                <div class="transect-species-list">
                    @foreach ($speciesDistribution as $entry)
                        <div>
                            <em>{{ $entry['species'] }}</em>
                            <strong>{{ $entry['count'] }}</strong>
                        </div>
                    @endforeach
                </div>
            @endif
        </article>
    </section>

    <article class="detail-card">
        <h3>Linked Observation Points</h3>
        @if ($transect->observations->isEmpty())
            <div class="empty-card compact-empty">No mangrove observations are linked to this transect.</div>
        @else
            <div class="table-wrap">
                <table class="transect-observation-table">
                    <thead>
                        <tr>
                            <th>Record</th>
                            <th>Species</th>
                            <th>Height</th>
                            <th>Canopy Width</th>
                            <th>GPS</th>
                            <th>Captured</th>
                            @if ($canViewAll)<th>Action</th>@endif
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($transect->observations as $record)
                            @php
                                $speciesName = $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Unidentified';
                                $height = $record->height_m ?? $record->measurement?->height_m;
                                $canopy = $record->canopy_width_m ?? $record->measurement?->canopy_width_m;
                            @endphp
                            <tr>
                                <td><strong>{{ $record->record_code }}</strong></td>
                                <td><em>{{ $speciesName }}</em></td>
                                <td>{{ $height !== null ? number_format((float) $height, 2) . ' m' : 'N/A' }}</td>
                                <td>{{ $canopy !== null ? number_format((float) $canopy, 2) . ' m' : 'N/A' }}</td>
                                <td>{{ $record->latitude !== null && $record->longitude !== null ? $record->latitude . ', ' . $record->longitude : 'N/A' }}</td>
                                <td>{{ ($record->captured_at ?? $record->created_at)?->format('M d, Y h:i A') ?? 'N/A' }}</td>
                                @if ($canViewAll)
                                    <td><a href="{{ route('admin.scan-monitoring.show', $record) }}" class="icon-button">View Scan</a></td>
                                @endif
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </article>

    <article class="detail-card">
        <h3>GPS Point Log</h3>
        <div class="table-wrap">
            <table class="compact-table transect-point-table">
                <thead>
                    <tr><th>Sequence</th><th>Latitude</th><th>Longitude</th><th>Accuracy</th><th>Altitude</th><th>Timestamp</th></tr>
                </thead>
                <tbody>
                    @foreach ($transect->points as $point)
                        <tr>
                            <td>{{ $point->sequence_number }}</td>
                            <td>{{ $point->latitude }}</td>
                            <td>{{ $point->longitude }}</td>
                            <td>{{ $point->accuracy_m !== null ? number_format((float) $point->accuracy_m, 1) . ' m' : 'N/A' }}</td>
                            <td>{{ $point->altitude_m !== null ? number_format((float) $point->altitude_m, 1) . ' m' : 'N/A' }}</td>
                            <td>{{ $point->recorded_at?->format('M d, Y h:i:s A') ?? 'N/A' }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    </article>

    <p class="transect-disclaimer">
        This GPS-based transect is an estimation and ecological documentation aid. Apply the study's accepted field protocol and calibrated survey instruments whenever formal scientific measurement is required.
    </p>
@endsection

@push('scripts')
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    @include('admin.partials.map-imagery')
    <script>
        const transect = @json($mapTransect);
        const coordinates = transect.points.map((point) => [point.latitude, point.longitude]);
        const center = coordinates.length > 0 ? coordinates[0] : [10.3347, 125.0750];
        const map = L.map('transect-detail-map', { preferCanvas: true, maxZoom: 24, zoomSnap: 0.5, zoomDelta: 0.5 }).setView(center, coordinates.length > 0 ? 16 : 9);
        const mapTheme = getComputedStyle(document.documentElement);
        const mapColor = (property, fallback) => mapTheme.getPropertyValue(property).trim() || fallback;
        const mapColors = {
            gps: mapColor('--map-gps', '#276749'),
            manual: mapColor('--map-manual', '#2B6CB0'),
            start: mapColor('--map-start', '#276749'),
            end: mapColor('--map-end', '#B54747'),
            observation: mapColor('--map-observation', '#A96612'),
            outline: mapColor('--map-outline', '#FFFFFF'),
        };

        const streetLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 24,
            maxNativeZoom: 19,
            attribution: '&copy; OpenStreetMap contributors',
        }).addTo(map);
        const satelliteLayer = L.silvaFallbackLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
            maxZoom: 24,
            maxNativeZoom: 19,
            attribution: 'Tiles &copy; Esri, Earthstar Geographics, and the GIS User Community',
        });
        L.control.layers({ Street: streetLayer, Satellite: satelliteLayer }).addTo(map);

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
        const observationIcon = () => L.divIcon({
            className: 'transect-observation-icon',
            html: '<span aria-hidden="true">O</span>',
            iconSize: [24, 24],
            iconAnchor: [12, 12],
        });

        if (coordinates.length >= 2) {
            const isGps = transect.mode === 'gps_tracking';
            const lineColor = isGps ? mapColors.gps : mapColors.manual;
            const segments = transect.segments.length ? transect.segments : [[transect.points[0], transect.points[transect.points.length - 1]]];
            segments.forEach((segment, index) => {
                const start = [segment[0].latitude, segment[0].longitude];
                const end = [segment[1].latitude, segment[1].longitude];
                L.polyline([start, end], { color: mapColors.outline, weight: 12, opacity: 0.98, dashArray: isGps ? null : '14 9' }).addTo(map);
                L.polyline([start, end], { color: lineColor, weight: 8, opacity: 1, dashArray: isGps ? null : '14 9' }).addTo(map);
                L.marker([(start[0] + end[0]) / 2, (start[1] + end[1]) / 2], {
                    icon: endpointIcon(escapeHtml(transect.map_label.slice(1)), lineColor),
                }).addTo(map).bindPopup(`${escapeHtml(transect.map_label)} line`);
                L.marker(start, { icon: endpointIcon('S', mapColors.start) }).addTo(map).bindPopup(`${escapeHtml(transect.map_label)} segment ${index + 1} start`);
                L.marker(end, { icon: endpointIcon('E', mapColors.end) }).addTo(map).bindPopup(`${escapeHtml(transect.map_label)} segment ${index + 1} end`);
            });
        }

        const bounds = transect.segments.length
            ? transect.segments.flatMap((segment) => segment.map((point) => [point.latitude, point.longitude]))
            : [coordinates[0], coordinates[coordinates.length - 1]].filter(Boolean);
        transect.observations.forEach((observation) => {
            const coordinate = [observation.latitude, observation.longitude];
            bounds.push(coordinate);
            L.marker(coordinate, {
                icon: observationIcon(),
                title: `Observation ${observation.record_code}`,
                alt: `Observation ${observation.record_code}`,
            }).addTo(map).bindPopup(`
                <strong>${escapeHtml(observation.record_code)}</strong><br>
                <em>${escapeHtml(observation.species)}</em>
            `);
        });

        if (bounds.length > 0) {
            map.fitBounds(bounds, { padding: [48, 48], maxZoom: 21 });
        }
    </script>
@endpush
