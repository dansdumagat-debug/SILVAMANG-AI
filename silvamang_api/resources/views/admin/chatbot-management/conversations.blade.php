@extends('admin.layouts.app')
@section('title', 'Conversation History')
@section('content')
    <div class="page-heading">
        <div><h2>Conversation History</h2><p>Saved chatbot activity, newest first.</p></div>
        <a href="{{ route('admin.chatbot-management.index') }}" class="neutral-action">Back to Chatbot</a>
    </div>
    <article class="panel">
        <form method="GET" class="filter-toolbar">
            <input type="search" name="search" value="{{ request('search') }}" placeholder="Search questions" aria-label="Search questions">
            <button class="small-button" type="submit">Search</button>
            <a class="reset-link" href="{{ route('admin.chatbot-management.conversations') }}">Reset</a>
        </form>
        @include('admin.chatbot-management._conversations', ['fullHistory' => true])
        @include('admin.partials.pagination', ['paginator' => $recentLogs])
    </article>
@endsection
