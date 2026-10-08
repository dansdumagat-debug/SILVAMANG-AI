<span class="settings-icon" aria-hidden="true">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" focusable="false">
        @switch($icon)
            @case('map')
                <path d="M18 8c0 4-6 9-6 9S6 12 6 8a6 6 0 1 1 12 0Z"/><circle cx="12" cy="8" r="2"/><path d="m5 15-3 6h20l-3-6"/>
                @break
            @case('ruler')
                <path d="m3 15 12-12 6 6L9 21l-6-6Z M12 6l3 3 M9 9l2 2 M6 12l3 3"/>
                @break
            @case('export')
                <path d="M14 2H5v20h14V7l-5-5Z M14 2v6h5 M8 12h8 M8 16h8"/>
                @break
            @case('account')
                <circle cx="12" cy="7" r="4"/><path d="M4 21v-3a8 5 0 0 1 16 0v3H4Z"/>
                @break
            @case('lock')
                <rect x="4" y="10" width="16" height="12" rx="2"/><path d="M7 10V7a5 5 0 0 1 10 0v3 M12 15v3"/>
                @break
            @default
                <path d="m9 2-1 3-3 1-3 4 2 2-2 2 3 4 3 1 1 3h6l1-3 3-1 3-4-2-2 2-2-3-4-3-1-1-3H9Z"/><circle cx="12" cy="12" r="4"/>
        @endswitch
    </svg>
</span>
