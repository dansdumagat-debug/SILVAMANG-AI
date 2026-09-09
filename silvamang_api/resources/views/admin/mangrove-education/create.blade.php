@extends('admin.layouts.app')

@section('title', 'Add Educational Content')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Add Mangrove Educational Content</h2>
            <p>Create structured species learning content for the mobile result page.</p>
        </div>
    </div>

    <form method="POST" action="{{ route('admin.mangrove-education.store') }}" class="form-card">
        @include('admin.mangrove-education._form', ['submitLabel' => 'Create Education'])
    </form>
@endsection
