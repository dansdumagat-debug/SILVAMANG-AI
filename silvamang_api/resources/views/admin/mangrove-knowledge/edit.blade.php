@extends('admin.layouts.app')

@section('title', 'Edit Mangrove Knowledge')

@section('content')
    <div class="page-heading">
        <div>
            <h2>Edit Mangrove Knowledge</h2>
            <p>Update verified educational content used by the assistant.</p>
        </div>
    </div>

    <form method="POST" action="{{ route('admin.mangrove-knowledge.update', $knowledge) }}" class="form-card">
        @method('PUT')
        @include('admin.mangrove-knowledge._form', ['submitLabel' => 'Update Knowledge'])
    </form>
@endsection
