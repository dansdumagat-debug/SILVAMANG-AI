@extends('admin.layouts.app')

@section('title', 'Scan Records')

@section('content')
    <div class="page-heading"><div><h2>Scan Records</h2><p>Monitor mobile scan submissions and validation state.</p></div></div>
    <article class="panel">
        <form method="GET" action="{{ route('admin.scan-records.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search record, species, location...">
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
            <input type="date" name="date_from" value="{{ request('date_from') }}">
            <input type="date" name="date_to" value="{{ request('date_to') }}">
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.scan-records.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($scanRecords->isEmpty())
            <div class="empty-card">No scan records match the current filters.</div>
        @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>Record Code</th><th>Species</th><th>Confidence</th><th>Location</th><th>Validation</th><th>Date</th><th>Actions</th></tr></thead>
                <tbody>
                    @foreach ($scanRecords as $record)
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
        <div class="pagination-wrap">{{ $scanRecords->links() }}</div>
        @endif
    </article>
@endsection
