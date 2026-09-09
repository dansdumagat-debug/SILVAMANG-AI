@extends('admin.layouts.app')

@section('title', 'Mangrove Knowledge')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Mangrove Knowledge Management</h2>
            <p>Maintain verified educational content for the hybrid AI assistant.</p>
        </div>
        <a href="{{ route('admin.mangrove-knowledge.create') }}" class="primary-action">Add Knowledge</a>
    </div>

    <article class="panel">
        <form method="GET" action="{{ route('admin.mangrove-knowledge.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search questions, answers, species, sources...">
            <select name="category">
                <option value="">All categories</option>
                @foreach ($categories as $category)
                    <option value="{{ $category }}" @selected(request('category') === $category)>
                        {{ str_replace('_', ' ', ucfirst($category)) }}
                    </option>
                @endforeach
            </select>
            <select name="status">
                <option value="">All statuses</option>
                @foreach ($statuses as $status)
                    <option value="{{ $status }}" @selected(request('status') === $status)>
                        {{ ucfirst($status) }}
                    </option>
                @endforeach
            </select>
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.mangrove-knowledge.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($knowledgeItems->isEmpty())
            <div class="empty-card">No knowledge entries match the current filters.</div>
        @else
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Category</th>
                            <th>Question</th>
                            <th>Species</th>
                            <th>Status</th>
                            <th>Keywords</th>
                            <th>Reference</th>
                            <th>Created</th>
                            <th>Updated</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($knowledgeItems as $item)
                            <tr>
                                <td>{{ str_replace('_', ' ', ucfirst($item->category)) }}</td>
                                <td>
                                    <strong>{{ $item->question }}</strong>
                                    <p class="muted">{{ \Illuminate\Support\Str::limit($item->answer, 120) }}</p>
                                </td>
                                <td>{{ $item->species_name ?? 'N/A' }}</td>
                                <td>@include('admin.partials.status-badge', ['status' => $item->status ?? 'active'])</td>
                                <td>{{ $item->keywords ?? 'N/A' }}</td>
                                <td>{{ $item->reference_source ?? 'N/A' }}</td>
                                <td>{{ $item->created_at?->format('M d, Y') }}</td>
                                <td>{{ $item->updated_at?->format('M d, Y') }}</td>
                                <td>
                                    <div class="action-row">
                                        <a href="{{ route('admin.mangrove-knowledge.edit', $item) }}" class="icon-button">Edit</a>
                                        <form method="POST" action="{{ route('admin.mangrove-knowledge.destroy', $item) }}" class="inline-delete" onsubmit="return confirm('Delete this knowledge entry?')">
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
            <div class="pagination-wrap">{{ $knowledgeItems->links() }}</div>
        @endif
    </article>
@endsection
