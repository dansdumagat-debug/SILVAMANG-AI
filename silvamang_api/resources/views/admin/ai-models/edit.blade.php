@extends('admin.layouts.app')

@section('title', 'Edit AI Model')

@section('content')
    <div class="page-heading"><div><h2>Edit AI Model</h2><p>Update model metadata and metrics.</p></div></div>
    <form method="POST" action="{{ route('admin.ai-models.update', $aiModel) }}" class="form-card">
        @method('PUT')
        @include('admin.ai-models._form', ['submitLabel' => 'Update AI Model'])
    </form>
@endsection
