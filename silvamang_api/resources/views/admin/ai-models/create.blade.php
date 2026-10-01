@extends('admin.layouts.app')

@section('title', 'Add AI Model')

@section('content')
    <div class="page-heading"><div><h2>Add AI Model</h2><p>Create an AI model tracking record.</p></div></div>
    <form method="POST" action="{{ route('admin.ai-models.store') }}" class="form-card">
        <p class="helper-text">This form saves model tracking metadata. It does not upload, train, or deploy a model.</p>
        @include('admin.ai-models._form', ['submitLabel' => 'Create AI Model'])
    </form>
@endsection
