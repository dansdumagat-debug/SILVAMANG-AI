@extends('admin.layouts.app')

@section('title', 'Edit Educational Content')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Edit Mangrove Educational Content</h2>
            <p>Update species learning sections shown after AI identification.</p>
        </div>
    </div>

    <form method="POST" action="{{ route('admin.mangrove-education.update', $education) }}" class="form-card">
        @method('PUT')
        @include('admin.mangrove-education._form', ['submitLabel' => 'Update Education'])
    </form>
@endsection
