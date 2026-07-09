@extends('admin.layouts.app')

@section('title', 'Add User')

@section('content')
    <div class="page-heading">
        <div><h2>Add User</h2><p>Create a backend, researcher, or mobile user account.</p></div>
        <a href="{{ route('admin.users.index') }}" class="secondary-action">Back</a>
    </div>

    <form method="POST" action="{{ route('admin.users.store') }}" class="form-card">
        @csrf
        @include('admin.users._form', ['mode' => 'create'])
        <div class="form-actions">
            <button type="submit" class="primary-action">Create User</button>
            <a href="{{ route('admin.users.index') }}" class="secondary-action">Cancel</a>
        </div>
    </form>
@endsection
