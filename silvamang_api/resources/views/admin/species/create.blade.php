@extends('admin.layouts.app')

@section('title', 'Add Species')

@section('content')
    <div class="page-heading"><div><h2>Add Species</h2><p>Create a new mangrove species record.</p></div></div>
    <form method="POST" action="{{ route('admin.species.store') }}" class="form-card">
        @include('admin.species._form', ['submitLabel' => 'Create Species'])
    </form>
@endsection
