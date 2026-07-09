@extends('admin.layouts.app')

@section('title', 'Dashboard Overview')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Dashboard Overview</h2>
            <p>Welcome back, Admin. Here's what's happening with SILVAMANG AI.</p>
        </div>
        <div class="date-chip">{{ now()->format('M d, Y') }}</div>
    </div>

    <section class="stats-grid">
        @include('admin.partials.stat-card', ['label' => 'Total Scans', 'value' => $totalScans, 'hint' => 'All recorded scans', 'icon' => 'SC'])
        @include('admin.partials.stat-card', ['label' => 'Identified Species', 'value' => $totalSpecies, 'hint' => 'Species database', 'icon' => 'SP'])
        @include('admin.partials.stat-card', ['label' => 'Active Users', 'value' => $activeUsers, 'hint' => 'Registered accounts', 'icon' => 'US'])
        @include('admin.partials.stat-card', ['label' => 'AI Accuracy', 'value' => $averageAiAccuracy . '%', 'hint' => 'Average model score', 'icon' => 'AI'])
        @include('admin.partials.stat-card', ['label' => 'Height Measurements', 'value' => $measurementCount, 'hint' => 'Measurement records', 'icon' => 'HT'])
        @include('admin.partials.stat-card', ['label' => 'Validation Matches', 'value' => $validationMatchCount, 'hint' => 'Location matches', 'icon' => 'OK'])
    </section>

    <section class="dashboard-grid">
        <article class="panel report-card">
            <div class="panel-header"><h3>AI Model Health</h3><span>{{ $openAlertCount }} open alerts</span></div>
            <div class="metric-grid">
                <div><span>Active Models</span><strong>{{ $aiModelHealth['active_models'] }}</strong></div>
                <div><span>Total Models</span><strong>{{ $aiModelHealth['total_models'] }}</strong></div>
                <div><span>Average Accuracy</span><strong>{{ $aiModelHealth['average_accuracy'] }}%</strong></div>
                <div><span>Average F1</span><strong>{{ $aiModelHealth['average_f1'] }}%</strong></div>
            </div>
        </article>

        <article class="panel report-card">
            <div class="panel-header"><h3>7-Day Scan Volume</h3><span>{{ $scanTrend->sum('count') }} scans</span></div>
            @include('admin.partials.mini-bar-chart', ['items' => $scanTrend])
        </article>
    </section>

    <section class="dashboard-grid">
        <article class="panel report-card">
            <div class="panel-header"><h3>Top Identified Species</h3><span>Top 5</span></div>
            @forelse ($topIdentifiedSpecies as $species)
                @include('admin.partials.progress-bar', ['label' => $species->name, 'value' => $species->total, 'max' => max(1, $topIdentifiedSpecies->max('total')), 'suffix' => ' scans'])
            @empty
                <div class="empty-card">No species identification data yet.</div>
            @endforelse
        </article>

        <article class="panel report-card">
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
    </section>

    <section class="dashboard-grid">
        <article class="panel wide">
            <div class="panel-header"><h3>Recent Identifications</h3><span>Latest 5</span></div>
            @if ($latestScanRecords->isEmpty())
                <div class="empty-card">No recent scan records yet.</div>
            @else
                <div class="table-wrap">
                    <table class="compact-table report-table">
                        <thead><tr><th>Record Code</th><th>Species</th><th>Confidence</th><th>Validation</th><th>Location</th><th>Date</th><th>Action</th></tr></thead>
                        <tbody>
                            @foreach ($latestScanRecords as $record)
                                <tr>
                                    <td>{{ $record->record_code }}</td>
                                    <td>{{ $record->top_scientific_name ?? $record->species?->scientific_name ?? 'Pending' }}</td>
                                    <td>@include('admin.partials.confidence-bar', ['value' => $record->confidence])</td>
                                    <td>@include('admin.partials.status-badge', ['status' => $record->validation_status])</td>
                                    <td>{{ $record->location_name ?? 'N/A' }}</td>
                                    <td>{{ $record->created_at?->format('M d, Y') }}</td>
                                    <td><a href="{{ route('admin.scan-records.show', $record) }}" class="icon-button">View</a></td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            @endif
        </article>

        <article class="panel report-card">
            <div class="panel-header"><h3>Recent Alerts</h3><span>Latest 5</span></div>
            <div class="activity-list">
                @forelse ($latestAlerts as $alert)
                    <a href="{{ route('admin.alerts.show', $alert) }}" class="activity-row">
                        <span class="severity-badge severity-{{ strtolower($alert->severity) }}">{{ $alert->severity }}</span>
                        <strong>{{ $alert->title }}</strong>
                        <small>{{ $alert->created_at?->format('M d, Y') }}</small>
                    </a>
                @empty
                    <div class="empty-card">No recent alerts yet.</div>
                @endforelse
            </div>
        </article>
    </section>
@endsection
