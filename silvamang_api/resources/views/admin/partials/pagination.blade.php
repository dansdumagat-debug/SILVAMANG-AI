@if ($paginator->hasPages())
    <nav class="record-pagination" aria-label="Record pages">
        @if ($paginator->onFirstPage())
            <span class="secondary-action" aria-disabled="true">Previous</span>
        @else
            <a class="secondary-action" rel="prev" href="{{ $paginator->previousPageUrl() }}">Previous</a>
        @endif
        <span aria-live="polite">Page {{ $paginator->currentPage() }} of {{ $paginator->lastPage() }}</span>
        @if ($paginator->hasMorePages())
            <a class="secondary-action" rel="next" href="{{ $paginator->nextPageUrl() }}">Next</a>
        @else
            <span class="secondary-action" aria-disabled="true">Next</span>
        @endif
    </nav>
@endif
