@extends('admin.layouts.app')

@section('title', 'Educational Content')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Mangrove Educational Content Management</h2>
            <p>Maintain structured species lessons shown after AI identification.</p>
        </div>
        <a href="{{ route('admin.mangrove-education.create') }}" class="primary-action">Add Education</a>
    </div>

    <article class="panel">
        <form method="GET" action="{{ route('admin.mangrove-education.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search species, overview, history...">
            <select name="species_id">
                <option value="">All species</option>
                @foreach ($speciesList as $species)
                    <option value="{{ $species->id }}" @selected((string) request('species_id') === (string) $species->id)>
                        {{ $species->scientific_name }}
                    </option>
                @endforeach
            </select>
            <select name="status">
                <option value="">All statuses</option>
                @foreach ($statuses as $status)
                    <option value="{{ $status }}" @selected(request('status') === $status)>{{ ucfirst($status) }}</option>
                @endforeach
            </select>
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.mangrove-education.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($educationItems->isEmpty())
            <div class="empty-card">No educational species content matches the current filters.</div>
        @else
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Species</th>
                            <th>Family</th>
                            <th>Overview</th>
                            <th>Sections</th>
                            <th>Status</th>
                            <th>Updated</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($educationItems as $item)
                            <tr>
                                <td>
                                    <strong>{{ $item->species?->scientific_name ?? 'Unknown species' }}</strong>
                                    <p class="muted">{{ $item->species?->common_name ?? 'N/A' }}</p>
                                </td>
                                <td>{{ $item->species?->family ?? 'N/A' }}</td>
                                <td>{{ \Illuminate\Support\Str::limit($item->overview ?? 'No overview entered.', 140) }}</td>
                                <td>
                                    {{ collect([
                                        $item->physical_characteristics ? 'physical' : null,
                                        $item->habitat ? 'habitat' : null,
                                        $item->ecological_importance ? 'ecology' : null,
                                        $item->history ? 'history' : null,
                                        $item->scientific_study ? 'study' : null,
                                        $item->conservation_information ? 'conservation' : null,
                                    ])->filter()->join(', ') ?: 'N/A' }}
                                </td>
                                <td>@include('admin.partials.status-badge', ['status' => $item->status])</td>
                                <td>{{ $item->updated_at?->format('M d, Y') }}</td>
                                <td>
                                    <div class="action-row">
                                        <a href="{{ route('admin.mangrove-education.edit', $item) }}" class="icon-button">Edit</a>
                                        <form method="POST" action="{{ route('admin.mangrove-education.destroy', $item) }}" class="inline-delete" onsubmit="return confirm('Delete this educational content?')">
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
            <div class="pagination-wrap">{{ $educationItems->links() }}</div>
        @endif
    </article>
@endsection
