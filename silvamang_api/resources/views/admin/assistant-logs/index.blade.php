@extends('admin.layouts.app')

@section('title', 'AI Assistant Logs')

@section('content')
    <div class="page-heading"><div><h2>AI Assistant Logs</h2><p>Review logged assistant interactions and intent traces.</p></div></div>
    <article class="panel">
        <form method="GET" action="{{ route('admin.assistant-logs.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search user, question, response...">
            <select name="intent">
                <option value="">All intents</option>
                @foreach ($intents as $intent)
                    <option value="{{ $intent }}" @selected(request('intent') === $intent)>{{ $intent }}</option>
                @endforeach
            </select>
            <select name="source">
                <option value="">All sources</option>
                @foreach ($sources as $source)
                    <option value="{{ $source }}" @selected(request('source') === $source)>{{ $source }}</option>
                @endforeach
            </select>
            <input type="date" name="date_from" value="{{ request('date_from') }}">
            <input type="date" name="date_to" value="{{ request('date_to') }}">
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.assistant-logs.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($assistantLogs->isEmpty())
            <div class="empty-card">No assistant logs match the current filters.</div>
        @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>User</th><th>Question</th><th>Intent</th><th>Source</th><th>Date</th><th>Actions</th></tr></thead>
                <tbody>
                    @foreach ($assistantLogs as $log)
                        <tr>
                            <td>{{ $log->user?->name ?? 'N/A' }}</td>
                            <td>{{ \Illuminate\Support\Str::limit($log->question ?? 'N/A', 60) }}</td>
                            <td>{{ $log->intent ?? 'N/A' }}</td>
                            <td>{{ $log->source ?? 'N/A' }}</td>
                            <td>{{ $log->created_at?->format('M d, Y') }}</td>
                            <td><a href="{{ route('admin.assistant-logs.show', $log) }}" class="icon-button">View</a></td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        <div class="pagination-wrap">{{ $assistantLogs->links() }}</div>
        @endif
    </article>
@endsection
