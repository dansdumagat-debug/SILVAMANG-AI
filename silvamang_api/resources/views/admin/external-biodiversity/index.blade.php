@extends('admin.layouts.app')

@section('title', 'External Biodiversity Data')

@section('content')
    <div class="page-heading">
        <div>
            <h2>External Biodiversity Data Management</h2>
            <p>Manage cached iNaturalist references used as supporting biodiversity context for SILVAMANG AI results.</p>
        </div>
        <a href="{{ route('admin.species.index') }}" class="secondary-action">Species Management</a>
    </div>

    <section class="stats-grid">
        @include('admin.partials.stat-card', ['label' => 'Cached References', 'value' => $totalObservations, 'hint' => 'iNaturalist observation records', 'icon' => 'EXT'])
        @include('admin.partials.stat-card', ['label' => 'Species Covered', 'value' => $speciesWithReferences, 'hint' => 'Local species with cache', 'icon' => 'SPP'])
        @include('admin.partials.stat-card', ['label' => 'Images Cached', 'value' => $photosCached, 'hint' => 'Remote photo URLs stored', 'icon' => 'IMG'])
        @include('admin.partials.stat-card', ['label' => 'Last Sync', 'value' => $lastSyncedAt ? $lastSyncedAt->format('M d, Y') : 'N/A', 'hint' => $lastSyncedAt ? $lastSyncedAt->format('h:i A') : 'No sync yet', 'icon' => 'SYN'])
    </section>

    <section class="dashboard-grid">
        <article class="panel">
            <div class="panel-header">
                <div>
                    <h3>Refresh References</h3>
                    <span>Fetch current observation references from iNaturalist and cache them locally.</span>
                </div>
            </div>
            <form method="POST" action="{{ route('admin.external-biodiversity.refresh') }}" class="form-grid">
                @csrf
                <label class="form-group">
                    Species
                    <select name="species_id" required>
                        <option value="">Choose species</option>
                        @foreach ($speciesOptions as $species)
                            <option value="{{ $species->id }}">
                                {{ $species->scientific_name }}{{ $species->common_name ? ' / ' . $species->common_name : '' }}
                            </option>
                        @endforeach
                    </select>
                </label>
                <label class="form-group">
                    Limit
                    <select name="limit">
                        <option value="8">8 records</option>
                        <option value="12">12 records</option>
                        <option value="20">20 records</option>
                    </select>
                </label>
                <div class="form-actions form-wide">
                    <button type="submit" class="primary-action">Refresh / Update Cache</button>
                </div>
            </form>
        </article>

        <article class="panel">
            <div class="panel-header">
                <div>
                    <h3>Clear Cached Records</h3>
                    <span>Clear local reference cache only. Species, scan records, and AI results are not deleted.</span>
                </div>
            </div>
            <form method="POST" action="{{ route('admin.external-biodiversity.clear') }}" class="form-grid" onsubmit="return confirm('Clear cached external biodiversity references?')">
                @csrf
                @method('DELETE')
                <label class="form-group form-wide">
                    Species
                    <select name="species_id">
                        <option value="">All cached references</option>
                        @foreach ($speciesOptions as $species)
                            <option value="{{ $species->id }}">
                                {{ $species->scientific_name }}{{ $species->common_name ? ' / ' . $species->common_name : '' }}
                            </option>
                        @endforeach
                    </select>
                </label>
                <div class="form-actions form-wide">
                    <button type="submit" class="secondary-action">Clear Cached Records</button>
                </div>
            </form>
        </article>
    </section>

    <article class="panel">
        <form method="GET" action="{{ route('admin.external-biodiversity.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search observer, location, species...">
            <select name="species_id">
                <option value="">All species</option>
                @foreach ($speciesOptions as $species)
                    <option value="{{ $species->id }}" @selected((string) request('species_id') === (string) $species->id)>
                        {{ $species->scientific_name }}
                    </option>
                @endforeach
            </select>
            <select name="quality_grade">
                <option value="">All quality grades</option>
                @foreach ($qualityGrades as $grade)
                    <option value="{{ $grade }}" @selected(request('quality_grade') === $grade)>{{ ucfirst(str_replace('_', ' ', $grade)) }}</option>
                @endforeach
            </select>
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.external-biodiversity.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($observations->isEmpty())
            <div class="empty-card">
                No cached external biodiversity references yet. Choose a species above and refresh from iNaturalist.
            </div>
        @else
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Photo</th>
                            <th>Species</th>
                            <th>Observer</th>
                            <th>Location</th>
                            <th>Observed</th>
                            <th>Quality</th>
                            <th>Last Synced</th>
                            <th>Source</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($observations as $observation)
                            <tr>
                                <td>
                                    @if ($observation->photo_url)
                                        <img src="{{ $observation->photo_url }}" alt="iNaturalist observation photo" class="table-thumbnail">
                                    @else
                                        <span class="table-thumbnail-placeholder">No photo</span>
                                    @endif
                                </td>
                                <td>
                                    <strong>{{ $observation->species?->scientific_name ?? 'N/A' }}</strong>
                                    @if ($observation->species?->common_name)
                                        <span class="table-subtext">{{ $observation->species->common_name }}</span>
                                    @endif
                                </td>
                                <td>{{ $observation->observer ?? 'N/A' }}</td>
                                <td>
                                    {{ $observation->location ?? 'N/A' }}
                                    @if ($observation->latitude && $observation->longitude)
                                        <span class="table-subtext">{{ $observation->latitude }}, {{ $observation->longitude }}</span>
                                    @endif
                                </td>
                                <td>{{ $observation->observed_date?->format('M d, Y') ?? 'N/A' }}</td>
                                <td>@include('admin.partials.status-badge', ['status' => $observation->quality_grade ?? 'unknown'])</td>
                                <td>{{ $observation->updated_at?->format('M d, Y h:i A') ?? 'N/A' }}</td>
                                <td>
                                    <a href="https://www.inaturalist.org/observations/{{ $observation->source_observation_id }}" target="_blank" rel="noopener" class="icon-button">
                                        iNaturalist
                                    </a>
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            <div class="pagination-wrap">{{ $observations->links() }}</div>
        @endif
    </article>
@endsection
