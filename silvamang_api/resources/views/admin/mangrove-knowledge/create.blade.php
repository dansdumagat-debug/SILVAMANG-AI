@extends('admin.layouts.app')

@section('title', 'Add Mangrove Knowledge')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Add Mangrove Knowledge</h2>
            <p>Create a verified assistant answer for offline-first education.</p>
        </div>
    </div>

    <form method="POST" action="{{ route('admin.mangrove-knowledge.store') }}" class="form-card">
        @include('admin.mangrove-knowledge._form', ['submitLabel' => 'Create Knowledge'])
    </form>
@endsection
