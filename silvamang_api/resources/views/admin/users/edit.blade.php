@extends('admin.layouts.app')

@section('title', 'Edit User')

@section('content')
    <div class="page-heading">
        <div><h2>Edit User</h2><p>Update account details, roles, or password.</p></div>
        <div class="action-row">
            <a href="{{ route('admin.users.show', $user) }}" class="secondary-action">View</a>
            <a href="{{ route('admin.users.index') }}" class="secondary-action">Back</a>
        </div>
    </div>

    <section class="settings-grid">
        <form method="POST" action="{{ route('admin.users.update', $user) }}" class="form-card">
            @csrf
            @method('PUT')
            <h3>Account Details</h3>
            @include('admin.users._form', ['mode' => 'edit'])
            <div class="form-actions">
                <button type="submit" class="primary-action">Save Changes</button>
            </div>
        </form>

        <article class="form-card password-card">
            <h3>Password Reset</h3>
            <form method="POST" action="{{ route('admin.users.update-password', $user) }}">
                @csrf
                @method('PATCH')
                <div class="form-grid">
                    <label class="form-group">
                        New Password
                        <input type="password" name="password" required>
                    </label>
                    <label class="form-group">
                        Confirm Password
                        <input type="password" name="password_confirmation" required>
                    </label>
                </div>
                <div class="form-actions">
                    <button type="submit" class="primary-action">Update Password</button>
                </div>
            </form>
        </article>

        <article class="form-card full-width-card">
            <h3>Role Assignment</h3>
            <form method="POST" action="{{ route('admin.users.update-roles', $user) }}">
                @csrf
                @method('PATCH')
                <div class="checkbox-group">
                    @foreach ($roles as $role)
                        <label>
                            <input type="checkbox" name="roles[]" value="{{ $role->id }}" @checked($user->roles->contains($role))>
                            <span>{{ $role->display_name }}</span>
                        </label>
                    @endforeach
                </div>
                <div class="form-actions">
                    <button type="submit" class="primary-action">Update Roles</button>
                </div>
            </form>
        </article>
    </section>
@endsection
