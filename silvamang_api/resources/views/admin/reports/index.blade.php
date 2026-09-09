@extends('admin.layouts.app')

@section('title', 'Reports & Analytics')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Reports & Analytics</h2>
            <p>System performance, AI evaluation, and ecological monitoring summary.</p>
        </div>
        <div class="action-row report-print-actions">
            <button type="button" class="small-button" onclick="window.print()">Print Report</button>
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
        @include('admin.partials.analytics-card', ['label' => 'Uploaded Images', 'value' => $totalUploadedImages, 'hint' => 'Stored scan images', 'icon' => 'IM'])
        @include('admin.partials.analytics-card', ['label' => 'Species', 'value' => $totalSpecies, 'hint' => 'Species database', 'icon' => 'SP'])
        @include('admin.partials.analytics-card', ['label' => 'Users', 'value' => $totalUsers, 'hint' => 'Registered accounts', 'icon' => 'US'])
        @include('admin.partials.analytics-card', ['label' => 'Measurements', 'value' => $totalMeasurements, 'hint' => 'Linked to filtered scans', 'icon' => 'MS'])
        @include('admin.partials.analytics-card', ['label' => 'Assistant Logs', 'value' => $totalAssistantLogs, 'hint' => 'Saved assistant interactions', 'icon' => 'LG'])
    </section>

    <section class="report-grid">
        <article class="report-card">
            <div class="panel-header"><h3>Scan Trend</h3><span>{{ $scanTrend->sum('count') }} scans</span></div>
            @include('admin.partials.mini-bar-chart', ['items' => $scanTrend])
        </article>

        <article class="report-card">
            <div class="panel-header"><h3>Identification Analytics</h3><span>Top species and scan status</span></div>
            <div class="metric-grid report-metric-grid">
                <div><span>Average Confidence</span><strong>{{ $averageConfidence }}%</strong></div>
                <div><span>Completed</span><strong>{{ $completedScans }}</strong></div>
                <div><span>Pending</span><strong>{{ $pendingScans }}</strong></div>
                <div><span>Failed</span><strong>{{ $failedScans }}</strong></div>
            </div>
            <hr class="report-divider">
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
            <div class="metric-grid report-metric-grid">
                <div><span>Match</span><strong>{{ $validationMatches }}</strong></div>
                <div><span>Mismatch</span><strong>{{ $validationMismatches }}</strong></div>
                <div><span>Likely Found</span><strong>{{ $validationLikelyFound }}</strong></div>
                <div><span>Unknown</span><strong>{{ $validationUnknown }}</strong></div>
            </div>
            <hr class="report-divider">
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
            <p class="report-note">Measurement values are based on stored measurement records. Prototype depth-estimation values should be interpreted with image angle and distance limitations.</p>
        </article>
    </section>

    <section class="report-grid">
        <article class="report-card">
            <div class="panel-header"><h3>AI Model Performance</h3><span>{{ $aiModelSummary['active_models'] }} active / {{ $aiModelSummary['total_models'] }} total</span></div>
            <div class="metric-list">
                @include('admin.partials.progress-bar', ['label' => 'Average Accuracy', 'value' => $aiModelSummary['average_accuracy'], 'max' => 100, 'suffix' => '%'])
                @include('admin.partials.progress-bar', ['label' => 'Average Precision', 'value' => $aiModelSummary['average_precision'], 'max' => 100, 'suffix' => '%'])
                @include('admin.partials.progress-bar', ['label' => 'Average Recall', 'value' => $aiModelSummary['average_recall'], 'max' => 100, 'suffix' => '%'])
                @include('admin.partials.progress-bar', ['label' => 'Average F1 Score', 'value' => $aiModelSummary['average_f1'], 'max' => 100, 'suffix' => '%'])
                @include('admin.partials.progress-bar', ['label' => 'Top-K Accuracy', 'value' => $aiModelSummary['average_top_k'], 'max' => 100, 'suffix' => '%'])
            </div>
        </article>

        <article class="report-card">
            <div class="panel-header"><h3>Uploaded Images & Dataset</h3><span>Evidence readiness</span></div>
            <div class="metric-grid">
                <div><span>Total Images</span><strong>{{ $imageSummary['total'] }}</strong></div>
                <div><span>Verified</span><strong>{{ $imageSummary['verified'] }}</strong></div>
                <div><span>Dataset Species</span><strong>{{ $datasetSummary['species_count'] }}</strong></div>
                <div><span>Dataset Images</span><strong>{{ $datasetSummary['image_count'] }}</strong></div>
            </div>
            <p class="report-note">{{ $datasetSummary['note'] }}</p>
        </article>
    </section>

    <section class="report-grid">
        <article class="report-card wide-report-card">
            <div class="panel-header"><h3>CNN Baseline Evaluation</h3><span>File-based evidence</span></div>
            @if (! empty($cnnMetrics))
                <div class="cnn-metric-grid">
                    <div><span>Accuracy</span><strong>{{ $cnnMetrics['accuracy'] ?? 'N/A' }}%</strong></div>
                    <div><span>Precision</span><strong>{{ $cnnMetrics['precision'] ?? 'N/A' }}%</strong></div>
                    <div><span>Recall</span><strong>{{ $cnnMetrics['recall'] ?? 'N/A' }}%</strong></div>
                    <div><span>F1-score</span><strong>{{ $cnnMetrics['f1_score'] ?? 'N/A' }}%</strong></div>
                    <div><span>Top-3 Accuracy</span><strong>{{ $cnnMetrics['top_3_accuracy'] ?? 'N/A' }}%</strong></div>
                </div>
                @if ($cnnConfusionMatrixPreview)
                    <div class="confusion-matrix-preview">
                        <span>Confusion Matrix</span>
                        <img src="{{ $cnnConfusionMatrixPreview }}" alt="CNN baseline confusion matrix">
                    </div>
                @endif
                @if (! empty($cnnClassificationReport))
                    <div class="table-wrap">
                        <table class="compact-table classification-report-table">
                            <thead><tr><th>Class</th><th>Precision</th><th>Recall</th><th>F1-score</th><th>Support</th></tr></thead>
                            <tbody>
                                @foreach ($cnnClassificationReport as $row)
                                    <tr>
                                        <td>{{ str_replace('_', ' ', $row['class'] ?? 'N/A') }}</td>
                                        <td>{{ isset($row['precision']) && is_numeric($row['precision']) ? round($row['precision'] * 100, 2) . '%' : 'N/A' }}</td>
                                        <td>{{ isset($row['recall']) && is_numeric($row['recall']) ? round($row['recall'] * 100, 2) . '%' : 'N/A' }}</td>
                                        <td>{{ isset($row['f1-score']) && is_numeric($row['f1-score']) ? round($row['f1-score'] * 100, 2) . '%' : 'N/A' }}</td>
                                        <td>{{ $row['support'] ?? 'N/A' }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                @endif
            @else
                <div class="empty-card">CNN evaluation metrics are not available yet. Run evaluate_cnn_baseline.py first.</div>
            @endif
        </article>

        <article class="report-card">
            <div class="panel-header"><h3>Assistant & Alerts</h3><span>Monitoring</span></div>
            <div class="metric-grid">
                <div><span>Total Assistant Logs</span><strong>{{ $totalAssistantLogs }}</strong></div>
                <div><span>Total Alerts</span><strong>{{ $totalAlerts }}</strong></div>
                @foreach ($alertSummary['statuses'] as $status => $count)
                    <div><span>{{ ucfirst($status) }} Alerts</span><strong>{{ $count }}</strong></div>
                @endforeach
            </div>
            <div class="severity-list">
                @foreach ($alertSummary['severities'] as $severity => $count)
                    <span class="severity-badge severity-{{ $severity }}">{{ ucfirst($severity) }}: {{ $count }}</span>
                @endforeach
            </div>
            @if ($assistantIntentSummary->isNotEmpty())
                <hr class="report-divider">
                @foreach ($assistantIntentSummary as $intent)
                    @include('admin.partials.progress-bar', ['label' => $intent->intent ?? 'unknown', 'value' => $intent->total, 'max' => max(1, $assistantIntentSummary->max('total')), 'suffix' => ' logs'])
                @endforeach
            @endif
        </article>
    </section>

    <article class="panel print-note">
        <strong>Print/Export Note</strong>
        <p>Use the Print Report button or your browser print dialog to save this page as PDF. Excel/PDF export is not implemented in this phase.</p>
    </article>

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
