@extends('admin.layouts.app')

@section('title', 'Location Validation')

@section('content')
    <div class="page-heading"><div><h2>Location Validation</h2><p>Check species-location consistency results.</p></div></div>
    <article class="panel">
        <form method="GET" action="{{ route('admin.location-validations.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search record, species, message...">
            <select name="result">
                <option value="">All results</option>
                @foreach ($results as $result)
                    <option value="{{ $result }}" @selected(request('result') === $result)>{{ $result }}</option>
                @endforeach
            </select>
            <select name="species_id">
                <option value="">All species</option>
                @foreach ($speciesOptions as $species)
                    <option value="{{ $species->id }}" @selected((string) request('species_id') === (string) $species->id)>{{ $species->scientific_name }}</option>
                @endforeach
            </select>
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.location-validations.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($validations->isEmpty())
            <div class="empty-card">No location validations match the current filters.</div>
        @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>Record Code</th><th>Species</th><th>Result</th><th>Distance</th><th>Validated At</th><th>Actions</th></tr></thead>
                <tbody>
                    @foreach ($validations as $validation)
                        <tr>
                            <td>{{ $validation->scanRecord?->record_code ?? 'N/A' }}</td>
                            <td>{{ $validation->species?->scientific_name ?? 'N/A' }}</td>
                            <td>@include('admin.partials.status-badge', ['status' => $validation->result])</td>
                            <td>{{ $validation->distance_to_known_distribution_km ? $validation->distance_to_known_distribution_km . ' km' : 'N/A' }}</td>
                            <td>{{ $validation->validated_at?->format('M d, Y') ?? 'N/A' }}</td>
                            <td><a href="{{ route('admin.location-validations.show', $validation) }}" class="icon-button">View</a></td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        <div class="pagination-wrap">{{ $validations->links() }}</div>
        @endif
    </article>
@endsection
