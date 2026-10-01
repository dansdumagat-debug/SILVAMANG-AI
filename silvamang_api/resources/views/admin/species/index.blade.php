@extends('admin.layouts.app')

@section('title', 'Species Management')

@section('content')
    <div class="page-heading">
        <div><h2>Species Management</h2><p>Review mangrove species records and taxonomy details.</p></div>
        <a href="{{ route('admin.species.create') }}" class="primary-action">Add Species</a>
    </div>
    <article class="panel">
        <form method="GET" action="{{ route('admin.species.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search species...">
            <select name="family">
                <option value="">All families</option>
                @foreach ($families as $family)
                    <option value="{{ $family }}" @selected(request('family') === $family)>{{ $family }}</option>
                @endforeach
            </select>
            <select name="conservation_status">
                <option value="">All conservation</option>
                @foreach ($conservationStatuses as $status)
                    <option value="{{ $status }}" @selected(request('conservation_status') === $status)>{{ $status }}</option>
                @endforeach
            </select>
            <select name="status">
                <option value="">All statuses</option>
                @foreach ($statuses as $status)
                    <option value="{{ $status }}" @selected(request('status') === $status)>{{ $status }}</option>
                @endforeach
            </select>
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.species.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($species->isEmpty())
            <div class="empty-card empty-state">
                <span class="empty-state-icon" aria-hidden="true">&#127807;</span>
                <h3>{{ request()->anyFilled(['search', 'family', 'conservation_status', 'status']) ? 'No matching species' : ($species->total() ? 'No species records on this page' : 'No species records yet') }}</h3>
                <p>Species information will appear here when records are available. Add a species or adjust your filters.</p>
                <a href="{{ route('admin.species.create') }}" class="primary-action">Add Species</a>
            </div>
        @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>Scientific Name</th><th>Common Name</th><th>Family</th><th>Conservation Status</th><th>Identification</th><th>Status</th><th>Actions</th></tr></thead>
                <tbody>
                    @foreach ($species as $item)
                        <tr>
                            <td>{{ $item->scientific_name }}</td>
                            <td>{{ $item->common_name ?? 'N/A' }}</td>
                            <td>{{ $item->family ?? 'N/A' }}</td>
                            <td>{{ $item->conservation_status ?? 'N/A' }}</td>
                            <td>{{ $item->cnn_supported ? 'CNN trained' : 'Guide only' }}</td>
                            <td>@include('admin.partials.status-badge', ['status' => $item->status])</td>
                            <td>
                                <div class="action-row">
                                    <a href="{{ route('admin.species.show', $item) }}" class="icon-button">View</a>
                                    <a href="{{ route('admin.species.edit', $item) }}" class="icon-button">Edit</a>
                                    <form method="POST" action="{{ route('admin.species.destroy', $item) }}" class="inline-delete" onsubmit="return confirm('Are you sure you want to delete this species?')">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="icon-button danger">Delete</button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        @endif
        @include('admin.partials.pagination', ['paginator' => $species])
    </article>
@endsection
