@extends('admin.layouts.app')

@section('title', 'Measurements')

@section('content')
    <div class="page-heading"><div><h2>Measurements</h2><p>Review height and canopy estimates from scan records.</p></div></div>
    <article class="panel">
        <form method="GET" action="{{ route('admin.measurements.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search record code...">
            <select name="measurement_method">
                <option value="">All methods</option>
                @foreach ($measurementMethods as $method)
                    <option value="{{ $method }}" @selected(request('measurement_method') === $method)>{{ $method }}</option>
                @endforeach
            </select>
            <input type="date" name="date_from" value="{{ request('date_from') }}">
            <input type="date" name="date_to" value="{{ request('date_to') }}">
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.measurements.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($measurements->isEmpty())
            <div class="empty-card">No measurements match the current filters.</div>
        @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>Record Code</th><th>Height</th><th>Canopy Width</th><th>Method</th><th>Confidence</th><th>Actions</th></tr></thead>
                <tbody>
                    @foreach ($measurements as $measurement)
                        <tr>
                            <td>{{ $measurement->scanRecord?->record_code ?? 'N/A' }}</td>
                            <td>{{ $measurement->height_m ? $measurement->height_m . ' m' : 'N/A' }}</td>
                            <td>{{ $measurement->canopy_width_m ? $measurement->canopy_width_m . ' m' : 'N/A' }}</td>
                            <td>{{ $measurement->measurement_method }}</td>
                            <td>@include('admin.partials.confidence-bar', ['value' => $measurement->confidence])</td>
                            <td><a href="{{ route('admin.measurements.show', $measurement) }}" class="icon-button">View</a></td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        <div class="pagination-wrap">{{ $measurements->links() }}</div>
        @endif
    </article>
@endsection
