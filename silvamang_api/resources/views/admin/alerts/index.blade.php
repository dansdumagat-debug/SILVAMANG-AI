@extends('admin.layouts.app')

@section('title', 'Alerts & Monitoring')

@section('content')
    <div class="page-heading"><div><h2>Alerts & Monitoring</h2><p>Review system alerts and monitoring signals.</p></div></div>
    <article class="panel">
        <form method="GET" action="{{ route('admin.alerts.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search alerts...">
            <select name="severity"><option value="">All severities</option>@foreach ($severities as $severity)<option value="{{ $severity }}" @selected(request('severity') === $severity)>{{ $severity }}</option>@endforeach</select>
            <select name="status"><option value="">All statuses</option>@foreach ($statuses as $status)<option value="{{ $status }}" @selected(request('status') === $status)>{{ $status }}</option>@endforeach</select>
            <select name="alert_type"><option value="">All types</option>@foreach ($alertTypes as $type)<option value="{{ $type }}" @selected(request('alert_type') === $type)>{{ $type }}</option>@endforeach</select>
            <input type="date" name="date_from" value="{{ request('date_from') }}">
            <input type="date" name="date_to" value="{{ request('date_to') }}">
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.alerts.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($alerts->isEmpty())
            <div class="empty-card">No alerts match the current filters.</div>
        @else
            <div class="table-wrap">
                <table>
                    <thead><tr><th>Type</th><th>Severity</th><th>Title</th><th>Related Scan Record</th><th>Status</th><th>Created At</th><th>Actions</th></tr></thead>
                    <tbody>
                        @foreach ($alerts as $alert)
                            <tr>
                                <td>{{ $alert->alert_type }}</td>
                                <td><span class="severity-badge severity-{{ strtolower($alert->severity) }}">{{ $alert->severity }}</span></td>
                                <td>{{ $alert->title }}</td>
                                <td>{{ $alert->relatedScanRecord?->record_code ?? 'N/A' }}</td>
                                <td>@include('admin.partials.status-badge', ['status' => $alert->status])</td>
                                <td>{{ $alert->created_at?->format('M d, Y') }}</td>
                                <td><a href="{{ route('admin.alerts.show', $alert) }}" class="icon-button">View</a></td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            <div class="pagination-wrap">{{ $alerts->links() }}</div>
        @endif
    </article>
@endsection
