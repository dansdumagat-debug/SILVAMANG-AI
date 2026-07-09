@extends('admin.layouts.app')

@section('title', 'Edit Species')

@section('content')
    <div class="page-heading"><div><h2>Edit Species</h2><p>Update taxonomy and identification information.</p></div></div>
    <form method="POST" action="{{ route('admin.species.update', $species) }}" class="form-card">
        @method('PUT')
        @include('admin.species._form', ['submitLabel' => 'Update Species'])
    </form>
@endsection
