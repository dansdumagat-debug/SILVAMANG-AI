@extends('admin.layouts.app')

@section('title', 'Users')

@section('content')
    <div class="page-heading">
        <div><h2>Users</h2><p>Manage admin, researcher, and mobile user accounts.</p></div>
        <a href="{{ route('admin.users.create') }}" class="primary-action">Add User</a>
    </div>
    <article class="panel">
        <form method="GET" action="{{ route('admin.users.index') }}" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search name or email...">
            <select name="role">
                <option value="">All roles</option>
                @foreach ($roles as $role)
                    <option value="{{ $role->name }}" @selected(request('role') === $role->name)>{{ $role->display_name }}</option>
                @endforeach
            </select>
            <button type="submit" class="small-button">Apply Filter</button>
            <a href="{{ route('admin.users.index') }}" class="reset-link">Reset</a>
        </form>

        @if ($users->isEmpty())
            <div class="empty-card">No users match the current filters.</div>
        @else
        <div class="table-wrap">
            <table>
                <thead><tr><th>Name</th><th>Email</th><th>Roles</th><th>Scan Records</th><th>Assistant Logs</th><th>Created At</th><th>Actions</th></tr></thead>
                <tbody>
                    @foreach ($users as $user)
                        <tr>
                            <td>{{ $user->name }}</td>
                            <td>{{ $user->email }}</td>
                            <td>
                                <div class="role-badge-list">
                                    @forelse ($user->roles as $role)
                                        <span class="role-badge">{{ $role->display_name }}</span>
                                    @empty
                                        <span class="muted-text">N/A</span>
                                    @endforelse
                                </div>
                            </td>
                            <td>{{ $user->scan_records_count }}</td>
                            <td>{{ $user->assistant_logs_count }}</td>
                            <td>{{ $user->created_at?->format('M d, Y') }}</td>
                            <td>
                                <div class="action-row">
                                    <a href="{{ route('admin.users.show', $user) }}" class="icon-button">View</a>
                                    <a href="{{ route('admin.users.edit', $user) }}" class="icon-button">Edit</a>
                                    <form method="POST" action="{{ route('admin.users.destroy', $user) }}" class="inline-delete" onsubmit="return confirm('Are you sure you want to delete this user?')">
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
        <div class="pagination-wrap">{{ $users->links() }}</div>
        @endif
    </article>
@endsection
