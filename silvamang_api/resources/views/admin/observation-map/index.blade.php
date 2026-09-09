@extends('admin.layouts.app')

@section('title', 'Observation Map')

@push('styles')
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
@endpush

@section('content')
    <div class="page-heading">
        <div>
            <h2>Observation Map</h2>
            <p>Monitor scanned mangrove observations on a satellite field map with species pins, timestamps, users, and validation status.</p>
        </div>
        <a href="{{ route('admin.scan-monitoring.index') }}" class="secondary-action">Scan Monitoring</a>
    </div>

    <section class="stats-grid observation-map-stats">
        @include('admin.partials.stat-card', ['label' => 'Matching Records', 'value' => $totalMatchingRecords, 'hint' => 'Included by current filters', 'icon' => 'OBS'])
        @include('admin.partials.stat-card', ['label' => 'Mapped Pins', 'value' => $markers->count(), 'hint' => 'Records with GPS coordinates', 'icon' => 'MAP'])
        @include('admin.partials.stat-card', ['label' => 'No Coordinates', 'value' => $recordsWithoutCoordinates, 'hint' => 'Saved without map pin', 'icon' => 'GPS'])
    </section>

    <article class="panel observation-map-panel">
        <div class="observation-map-shell observation-map-shell-app">
            <div id="observation-map" class="observation-map-canvas"></div>

            <div class="admin-map-floating-top">
                <div class="admin-map-title-row">
                    <div class="admin-map-title">
                        <span class="admin-map-title-icon">MAP</span>
                        <div>
                            <strong>Mangrove Map</strong>
                            <span>Satellite view with scan record pins</span>
                        </div>
                    </div>
                    <span class="admin-map-count" id="visible-pin-count">{{ $markers->count() }} pins</span>
                </div>

                <div class="admin-map-species-row" id="species-choice-row"></div>

                <details class="admin-map-filter-details">
                    <summary>Filters</summary>
                    <form method="GET" action="{{ route('admin.observation-map.index') }}" class="admin-map-filter-grid">
                        <input type="search" name="search" value="{{ request('search') }}" placeholder="Search species, record, user, barangay...">
                        <select name="species_id">
                            <option value="">All species</option>
                            @foreach ($speciesOptions as $species)
                                <option value="{{ $species->id }}" @selected((string) request('species_id') === (string) $species->id)>
                                    {{ $species->scientific_name }}
                                </option>
                            @endforeach
                        </select>
                        <select name="user_id">
                            <option value="">All users</option>
                            @foreach ($userOptions as $user)
                                <option value="{{ $user->id }}" @selected((string) request('user_id') === (string) $user->id)>
                                    {{ $user->name }} / {{ $user->email }}
                                </option>
                            @endforeach
                        </select>
                        <input type="search" name="barangay" value="{{ request('barangay') }}" placeholder="Barangay/location">
                        <select name="validation_status">
                            <option value="">All validation</option>
                            @foreach ($validationStatuses as $status)
                                <option value="{{ $status }}" @selected(request('validation_status') === $status)>{{ ucfirst(str_replace('_', ' ', $status)) }}</option>
                            @endforeach
                        </select>
                        <input type="number" step="0.01" min="0" max="100" name="confidence_min" value="{{ request('confidence_min') }}" placeholder="Min confidence">
                        <input type="number" step="0.01" min="0" max="100" name="confidence_max" value="{{ request('confidence_max') }}" placeholder="Max confidence">
                        <input type="date" name="date_from" value="{{ request('date_from') }}">
                        <input type="date" name="date_to" value="{{ request('date_to') }}">
                        <button type="submit" class="small-button">Apply Filter</button>
                        <a href="{{ route('admin.observation-map.index') }}" class="reset-link">Reset</a>
                    </form>
                </details>
            </div>

            @if ($markers->isEmpty())
                <div class="observation-map-empty">No mapped scan records match the current filters.</div>
            @endif

            <aside class="observation-details-panel observation-details-floating" id="observation-details">
                <button type="button" class="observation-details-close" id="detail-close" aria-label="Close details">x</button>
                <h3>Observation Details</h3>
                <p class="muted-text">Click a marker to review who scanned it, when it was scanned, species result, GPS coordinates, measurements, and validation status.</p>
                <div id="detail-image-wrap" class="observation-image-wrap"></div>
                <div class="detail-grid">
                    <div><span>Species</span><strong id="detail-species">Select a marker</strong></div>
                    <div><span>Confidence</span><strong id="detail-confidence">N/A</strong></div>
                    <div><span>Barangay</span><strong id="detail-barangay">N/A</strong></div>
                    <div><span>User</span><strong id="detail-user">N/A</strong></div>
                    <div><span>Scan Date</span><strong id="detail-date">N/A</strong></div>
                    <div><span>Scan Time</span><strong id="detail-time">N/A</strong></div>
                    <div><span>Height</span><strong id="detail-height">N/A</strong></div>
                    <div><span>Canopy Width</span><strong id="detail-canopy">N/A</strong></div>
                    <div><span>Latitude</span><strong id="detail-latitude">N/A</strong></div>
                    <div><span>Longitude</span><strong id="detail-longitude">N/A</strong></div>
                    <div><span>Validation</span><strong id="detail-validation">N/A</strong></div>
                    <div><span>Sync</span><strong id="detail-sync">N/A</strong></div>
                    <div><span>Created</span><strong id="detail-created">N/A</strong></div>
                    <div><span>Synced</span><strong id="detail-synced">N/A</strong></div>
                </div>
                <a id="detail-link" href="{{ route('admin.scan-monitoring.index') }}" class="primary-action">Open Scan Record</a>
            </aside>
        </div>
    </article>
@endsection

@push('scripts')
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script>
        const markers = @json($markers);
        const allSpeciesLabel = 'All species';
        const defaultCenter = [10.3347, 125.0750];
        let selectedSpecies = allSpeciesLabel;
        let selectedMarkerId = null;
        const leafletMarkers = [];

        const map = L.map('observation-map', {
            zoomControl: true,
            preferCanvas: true,
        }).setView(defaultCenter, 9);

        map.createPane('labels');
        map.getPane('labels').style.zIndex = 450;
        map.getPane('labels').style.pointerEvents = 'none';

        L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
            maxZoom: 19,
            attribution: 'Tiles &copy; Esri, Earthstar Geographics, and the GIS User Community',
        }).addTo(map);

        L.tileLayer('https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}', {
            maxZoom: 19,
            pane: 'labels',
            attribution: 'Labels &copy; Esri',
        }).addTo(map);

        const markerColor = (record) => {
            if (selectedMarkerId === record.id) {
                return '#2472B8';
            }

            const status = record.sync_status || record.validation_status;
            const normalized = String(status || '').toLowerCase();
            if (normalized.includes('synced') || normalized.includes('match') || normalized.includes('verified') || normalized.includes('online')) {
                return '#2F7D46';
            }
            if (normalized.includes('mismatch') || normalized.includes('failed')) {
                return '#A83B3B';
            }
            if (normalized.includes('pending')) {
                return '#F5A33B';
            }
            return '#2472B8';
        };

        const markerIcon = (record) => L.divIcon({
            className: 'observation-marker',
            html: `<span style="background:${markerColor(record)}"><i></i></span>`,
            iconSize: [40, 40],
            iconAnchor: [20, 20],
        });

        const setText = (id, value) => {
            document.getElementById(id).textContent =
                value === null || value === undefined || value === '' ? 'N/A' : value;
        };

        const formatLabel = (value) => {
            if (value === null || value === undefined || value === '') {
                return null;
            }

            return String(value)
                .replaceAll('_', ' ')
                .replace(/\b\w/g, (letter) => letter.toUpperCase());
        };

        const speciesLabel = (record) => {
            const species = String(record.species || '').trim();
            return species === '' ? 'Unknown species' : species;
        };

        const escapeHtml = (value) => {
            if (value === null || value === undefined || value === '') {
                return 'N/A';
            }

            return String(value)
                .replaceAll('&', '&amp;')
                .replaceAll('<', '&lt;')
                .replaceAll('>', '&gt;')
                .replaceAll('"', '&quot;')
                .replaceAll("'", '&#039;');
        };

        const visibleMarkers = () => {
            if (selectedSpecies === allSpeciesLabel) {
                return markers;
            }

            return markers.filter((record) => speciesLabel(record) === selectedSpecies);
        };

        const updatePinCount = () => {
            const count = visibleMarkers().length;
            document.getElementById('visible-pin-count').textContent =
                count === markers.length ? `${count} pins` : `${count} of ${markers.length} pins`;
        };

        const fitVisibleMarkers = () => {
            const bounds = visibleMarkers().map((record) => [record.latitude, record.longitude]);
            if (bounds.length > 0) {
                map.fitBounds(bounds, { padding: [46, 46], maxZoom: selectedSpecies === allSpeciesLabel ? 16 : 17 });
            }
        };

        const refreshMarkers = () => {
            leafletMarkers.forEach(({ marker, record }) => {
                const shouldShow = selectedSpecies === allSpeciesLabel || speciesLabel(record) === selectedSpecies;
                if (shouldShow && !map.hasLayer(marker)) {
                    marker.addTo(map);
                }
                if (!shouldShow && map.hasLayer(marker)) {
                    marker.removeFrom(map);
                }
                marker.setIcon(markerIcon(record));
            });

            updatePinCount();
        };

        const renderSpeciesChoices = () => {
            const row = document.getElementById('species-choice-row');
            const speciesChoices = [
                allSpeciesLabel,
                ...Array.from(new Set(markers.map(speciesLabel))).sort(),
            ];

            row.innerHTML = '';

            speciesChoices.forEach((species) => {
                const button = document.createElement('button');
                button.type = 'button';
                button.className = `admin-map-species-chip${species === selectedSpecies ? ' selected' : ''}`;
                button.dataset.species = species;
                button.textContent = species === allSpeciesLabel ? 'All species' : species;
                row.appendChild(button);
            });

            row.querySelectorAll('.admin-map-species-chip').forEach((button) => {
                button.addEventListener('click', () => {
                    selectedSpecies = button.dataset.species || allSpeciesLabel;
                    selectedMarkerId = null;
                    renderSpeciesChoices();
                    refreshMarkers();
                    hideDetails();
                    fitVisibleMarkers();
                });
            });
        };

        const hideDetails = () => {
            document.getElementById('observation-details').classList.remove('is-visible');
        };

        const showDetails = (record) => {
            selectedMarkerId = record.id;
            refreshMarkers();
            setText('detail-species', record.species);
            setText('detail-confidence', record.confidence === null ? null : `${record.confidence}%`);
            setText('detail-barangay', record.barangay);
            setText('detail-user', record.user);
            setText('detail-date', record.captured_date);
            setText('detail-time', record.captured_time);
            setText('detail-height', record.height_m === null ? null : `${record.height_m} m`);
            setText('detail-canopy', record.canopy_width_m === null ? null : `${record.canopy_width_m} m`);
            setText('detail-latitude', record.latitude);
            setText('detail-longitude', record.longitude);
            setText('detail-validation', formatLabel(record.validation_status));
            setText('detail-sync', formatLabel(record.sync_status));
            setText('detail-created', record.created_at);
            setText('detail-synced', record.synced_at);

            const imageWrap = document.getElementById('detail-image-wrap');
            imageWrap.innerHTML = record.image_url
                ? `<img src="${record.image_url}" alt="Captured mangrove scan image">`
                : '<div class="image-card-placeholder">Preview unavailable</div>';

            const detailLink = document.getElementById('detail-link');
            detailLink.href = record.detail_url;
            document.getElementById('observation-details').classList.add('is-visible');
        };

        document.getElementById('detail-close').addEventListener('click', () => {
            selectedMarkerId = null;
            refreshMarkers();
            hideDetails();
        });

        markers.forEach((record) => {
            const latLng = [record.latitude, record.longitude];

            const popupHtml = `
                <strong>${escapeHtml(record.species)}</strong><br>
                User: ${escapeHtml(record.user)}<br>
                Location: ${escapeHtml(record.barangay)}<br>
                Captured: ${escapeHtml(record.captured_date)} ${record.captured_time ? escapeHtml(record.captured_time) : ''}<br>
                Confidence: ${escapeHtml(record.confidence)}%<br>
                Measurements: Height ${escapeHtml(record.height_m)} m, Canopy ${escapeHtml(record.canopy_width_m)} m<br>
                Status: ${escapeHtml(formatLabel(record.validation_status))}<br>
                Sync: ${escapeHtml(formatLabel(record.sync_status))}
            `;

            const marker = L.marker(latLng, { icon: markerIcon(record) })
                .addTo(map)
                .bindPopup(popupHtml)
                .on('click', () => showDetails(record));

            leafletMarkers.push({ marker, record });
        });

        renderSpeciesChoices();
        updatePinCount();

        if (markers.length > 0) {
            fitVisibleMarkers();
        }
    </script>
@endpush
