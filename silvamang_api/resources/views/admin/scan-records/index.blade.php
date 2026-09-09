@extends('admin.layouts.app')

@section('title', 'Mangrove Scan Monitoring')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Mangrove Scan Monitoring</h2>
            <p>View complete scanning history across users, species, locations, timestamps, validation, and sync status.</p>
        </div>
        <a href="{{ route('admin.observation-map.index') }}" class="secondary-action">Observation Map</a>
    </div>

    <section class="stats-grid observation-map-stats">
        @include('admin.partials.stat-card', ['label' => 'Total Observations', 'value' => $totalScanRecords, 'hint' => 'All recorded scan records', 'icon' => 'OBS'])
        @include('admin.partials.stat-card', ['label' => 'Mapped Records', 'value' => $mappedScanRecords, 'hint' => 'Records with GPS coordinates', 'icon' => 'GPS'])
        @include('admin.partials.stat-card', ['label' => 'Captured Today', 'value' => $todayScanRecords, 'hint' => 'Based on captured timestamp', 'icon' => 'DAY'])
    </section>

    <article class="panel">
        <form method="GET" action="{{ route('admin.scan-monitoring.index') }}" class="filter-toolbar scan-monitoring-filter">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search ID, user, species, barangay...">
            <select name="sort">
                @foreach ($sortOptions as $value => $label)
                    <option value="{{ $value }}" @selected((request('sort') ?: 'latest_scan') === $value)>{{ $label }}</option>
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
            <select name="species_id">
                <option value="">All species</option>
                @foreach ($speciesOptions as $species)
                    <option value="{{ $species->id }}" @selected((string) request('species_id') === (string) $species->id)>{{ $species->scientific_name }}</option>
                @endforeach
            </select>
            <input type="search" name="location" value="{{ request('location') }}" placeholder="Barangay/location">
            <select name="identification_status">
                <option value="">All identification</option>
                @foreach ($identificationStatuses as $status)
                    <option value="{{ $status }}" @selected(request('identification_status') === $status)>{{ ucfirst(str_replace('_', ' ', $status)) }}</option>
                @endforeach
            </select>
            <select name="validation_status">
                <option value="">All validation</option>
                @foreach ($validationStatuses as $status)
                    <option value="{{ $status }}" @selected(request('validation_status') === $status)>{{ ucfirst(str_replace('_', ' ', $status)) }}</option>
                @endforeach
            </select>
            <input type="date" name="date_from" value="{{ request('date_from') }}">
            <input type="date" name="date_to" value="{{ request('date_to') }}">
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.scan-monitoring.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($scanRecords->isEmpty())
            <div class="empty-card">No scan records match the current filters.</div>
        @else
            <div class="table-wrap">
                <table class="scan-monitoring-table">
                    <thead>
                        <tr>
                            <th>Observation ID</th>
                            <th>Image</th>
                            <th>Date</th>
                            <th>Time</th>
                            <th>User</th>
                            <th>Species</th>
                            <th>Location</th>
                            <th>Confidence</th>
                            <th>Validation</th>
                            <th>Sync</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($scanRecords as $record)
                            @php
                                $observedAt = $record->captured_at ?? $record->created_at;
                                $location = $record->barangay ?: $record->manual_barangay ?: $record->location_name ?: $record->address;
                                $speciesName = $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Pending';
                                $image = $record->images->first();
                                $imageExists = $image?->image_path && \Illuminate\Support\Facades\Storage::disk('public')->exists($image->image_path);
                                $imageUrl = $imageExists ? asset('storage/' . $image->image_path) : null;
                                $syncStatus = $record->synced_at ? 'synced' : ($record->offline_reference ? 'pending_sync' : 'online');
                            @endphp
                            <tr>
                                <td>
                                    <strong>{{ $record->record_code }}</strong>
                                    <span class="table-subtext">#{{ $record->id }}</span>
                                </td>
                                <td>
                                    @if ($imageUrl)
                                        <img src="{{ $imageUrl }}" alt="Captured mangrove image" class="table-thumbnail">
                                    @else
                                        <span class="table-thumbnail-placeholder">No image</span>
                                    @endif
                                </td>
                                <td>{{ $observedAt?->format('M d, Y') ?? 'N/A' }}</td>
                                <td>{{ $observedAt?->format('h:i A') ?? 'N/A' }}</td>
                                <td>
                                    <strong>{{ $record->user?->name ?? 'N/A' }}</strong>
                                    <span class="table-subtext">{{ $record->user?->email ?? 'No user email' }}</span>
                                </td>
                                <td>
                                    <strong>{{ $speciesName }}</strong>
                                    <span class="table-subtext">{{ $record->top_common_name ?? $record->species?->common_name ?? 'No common name' }}</span>
                                </td>
                                <td>
                                    <strong>{{ $location ?? 'N/A' }}</strong>
                                    <span class="table-subtext">
                                        {{ $record->latitude && $record->longitude ? $record->latitude . ', ' . $record->longitude : 'GPS unavailable' }}
                                    </span>
                                </td>
                                <td>@include('admin.partials.confidence-bar', ['value' => $record->confidence])</td>
                                <td>@include('admin.partials.status-badge', ['status' => $record->validation_status])</td>
                                <td>@include('admin.partials.status-badge', ['status' => $syncStatus])</td>
                                <td><a href="{{ route('admin.scan-monitoring.show', $record) }}" class="icon-button">View Details</a></td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            <div class="pagination-wrap">{{ $scanRecords->links() }}</div>
        @endif
    </article>
@endsection
