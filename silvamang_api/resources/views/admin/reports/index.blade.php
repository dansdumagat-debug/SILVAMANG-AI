@extends('admin.layouts.app')

@section('title', 'Reports & Analytics')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Reports & Analytics</h2>
            <p>Monitor identification activity, AI performance, validation results, and ecological records.</p>
        </div>
    </div>

    <article class="panel">
        <form method="GET" action="{{ route('admin.reports.index') }}" class="filter-toolbar report-filter-toolbar">
            <input type="date" name="date_from" value="{{ request('date_from') }}" aria-label="Date from">
            <input type="date" name="date_to" value="{{ request('date_to') }}" aria-label="Date to">
            <select name="species_id">
                <option value="">All species</option>
                @foreach ($speciesOptions as $species)
                    <option value="{{ $species->id }}" @selected((string) request('species_id') === (string) $species->id)>{{ $species->scientific_name }}</option>
                @endforeach
            </select>
            <select name="identification_status">
                <option value="">All identification</option>
                @foreach ($identificationStatuses as $status)
                    <option value="{{ $status }}" @selected(request('identification_status') === $status)>{{ $status }}</option>
                @endforeach
            </select>
            <select name="validation_status">
                <option value="">All validation</option>
                @foreach ($validationStatuses as $status)
                    <option value="{{ $status }}" @selected(request('validation_status') === $status)>{{ $status }}</option>
                @endforeach
            </select>
            <button type="submit" class="small-button">Apply Filters</button>
            <a href="{{ route('admin.reports.index') }}" class="reset-link">Reset</a>
        </form>
    </article>

    <section class="analytics-grid summary-grid">
        @include('admin.partials.analytics-card', ['label' => 'Total Scans', 'value' => $totalScans, 'hint' => 'Filtered scan records', 'icon' => 'SC'])
        @include('admin.partials.analytics-card', ['label' => 'Completed Scans', 'value' => $completedScans, 'hint' => $pendingScans . ' pending', 'icon' => 'OK'])
        @include('admin.partials.analytics-card', ['label' => 'Average Confidence', 'value' => $averageConfidence . '%', 'hint' => 'Scan record confidence', 'icon' => 'AI'])
        @include('admin.partials.analytics-card', ['label' => 'Total Measurements', 'value' => $totalMeasurements, 'hint' => 'Linked to filtered scans', 'icon' => 'MS'])
        @include('admin.partials.analytics-card', ['label' => 'Validation Matches', 'value' => $validationMatches, 'hint' => 'Location status match', 'icon' => 'VM'])
        @include('admin.partials.analytics-card', ['label' => 'Validation Mismatches', 'value' => $validationMismatches, 'hint' => 'Needs review', 'icon' => 'VX'])
    </section>

    <section class="report-grid">
        <article class="report-card">
            <div class="panel-header"><h3>Scan Trend</h3><span>{{ $scanTrend->sum('count') }} scans</span></div>
            @include('admin.partials.mini-bar-chart', ['items' => $scanTrend])
        </article>

        <article class="report-card">
            <div class="panel-header"><h3>Top Identified Species</h3><span>Top 5</span></div>
            @forelse ($mostIdentifiedSpecies as $species)
                @include('admin.partials.progress-bar', ['label' => $species->name, 'value' => $species->total, 'max' => max(1, $mostIdentifiedSpecies->max('total')), 'suffix' => ' scans'])
            @empty
                <div class="empty-card">No species identification data yet.</div>
            @endforelse
        </article>
    </section>

    <section class="report-grid">
        <article class="report-card">
            <div class="panel-header"><h3>Validation Breakdown</h3><span>Status mix</span></div>
            @forelse ($validationBreakdown as $item)
                <div class="metric-row">
                    @include('admin.partials.status-badge', ['status' => $item['label']])
                    @include('admin.partials.progress-bar', ['label' => '', 'value' => $item['count'], 'max' => max(1, $validationBreakdown->max('count')), 'suffix' => ''])
                </div>
            @empty
                <div class="empty-card">No validation data yet.</div>
            @endforelse
        </article>

        <article class="report-card">
            <div class="panel-header"><h3>Measurement Summary</h3><span>{{ $measurementSummary['total'] }} records</span></div>
            <div class="metric-grid">
                <div><span>Average Height</span><strong>{{ $measurementSummary['average_height_m'] }} m</strong></div>
                <div><span>Average Canopy Width</span><strong>{{ $measurementSummary['average_canopy_width_m'] }} m</strong></div>
                <div><span>Average DBH</span><strong>{{ $measurementSummary['average_dbh_cm'] }} cm</strong></div>
                <div><span>Total Records</span><strong>{{ $measurementSummary['total'] }}</strong></div>
            </div>
        </article>
    </section>

    <section class="report-grid">
        <article class="report-card">
            <div class="panel-header"><h3>AI Model Performance</h3><span>{{ $aiModelSummary['active_models'] }} active</span></div>
            <div class="metric-list">
                @include('admin.partials.progress-bar', ['label' => 'Average Accuracy', 'value' => $aiModelSummary['average_accuracy'], 'max' => 100, 'suffix' => '%'])
                @include('admin.partials.progress-bar', ['label' => 'Average Precision', 'value' => $aiModelSummary['average_precision'], 'max' => 100, 'suffix' => '%'])
                @include('admin.partials.progress-bar', ['label' => 'Average Recall', 'value' => $aiModelSummary['average_recall'], 'max' => 100, 'suffix' => '%'])
                @include('admin.partials.progress-bar', ['label' => 'Average F1 Score', 'value' => $aiModelSummary['average_f1'], 'max' => 100, 'suffix' => '%'])
                @include('admin.partials.progress-bar', ['label' => 'Top-K Accuracy', 'value' => $aiModelSummary['average_top_k'], 'max' => 100, 'suffix' => '%'])
            </div>
        </article>

        <article class="report-card">
            <div class="panel-header"><h3>Alert Summary</h3><span>Monitoring</span></div>
            <div class="metric-grid">
                @foreach ($alertSummary['statuses'] as $status => $count)
                    <div><span>{{ ucfirst($status) }} Alerts</span><strong>{{ $count }}</strong></div>
                @endforeach
            </div>
            <div class="severity-list">
                @foreach ($alertSummary['severities'] as $severity => $count)
                    <span class="severity-badge severity-{{ $severity }}">{{ ucfirst($severity) }}: {{ $count }}</span>
                @endforeach
            </div>
        </article>
    </section>

    <section class="report-grid">
        <article class="report-card wide-report-card">
            <div class="panel-header"><h3>Recent Identification Records</h3><span>Latest 8</span></div>
            @if ($recentRecords->isEmpty())
                <div class="empty-card">No recent scan records yet.</div>
            @else
                <div class="table-wrap">
                    <table class="compact-table report-table">
                        <thead><tr><th>Record Code</th><th>Species</th><th>Confidence</th><th>Location</th><th>Validation</th><th>Date</th><th>Action</th></tr></thead>
                        <tbody>
                            @foreach ($recentRecords as $record)
                                <tr>
                                    <td>{{ $record->record_code }}</td>
                                    <td>{{ $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Pending' }}</td>
                                    <td>@include('admin.partials.confidence-bar', ['value' => $record->confidence])</td>
                                    <td>{{ $record->location_name ?? 'N/A' }}</td>
                                    <td>@include('admin.partials.status-badge', ['status' => $record->validation_status])</td>
                                    <td>{{ $record->created_at?->format('M d, Y') }}</td>
                                    <td><a href="{{ route('admin.scan-records.show', $record) }}" class="icon-button">View</a></td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            @endif
        </article>

        <article class="report-card">
            <div class="panel-header"><h3>Recent Alerts</h3><span>Latest 5</span></div>
            @if ($recentAlerts->isEmpty())
                <div class="empty-card">No recent alerts yet.</div>
            @else
                <div class="table-wrap">
                    <table class="compact-table report-table">
                        <thead><tr><th>Type</th><th>Severity</th><th>Title</th><th>Status</th><th>Date</th><th>Action</th></tr></thead>
                        <tbody>
                            @foreach ($recentAlerts as $alert)
                                <tr>
                                    <td>{{ $alert->alert_type }}</td>
                                    <td><span class="severity-badge severity-{{ strtolower($alert->severity) }}">{{ $alert->severity }}</span></td>
                                    <td>{{ $alert->title }}</td>
                                    <td>@include('admin.partials.status-badge', ['status' => $alert->status])</td>
                                    <td>{{ $alert->created_at?->format('M d, Y') }}</td>
                                    <td><a href="{{ route('admin.alerts.show', $alert) }}" class="icon-button">View</a></td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            @endif
        </article>
    </section>
@endsection
