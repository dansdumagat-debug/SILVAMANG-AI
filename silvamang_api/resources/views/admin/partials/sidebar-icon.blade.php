<svg class="sidebar-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">
    @switch($label)
        @case('Dashboard')
            <path d="m3 10 9-8 9 8 M5 9v12h5v-7h4v7h5V9"/>
            @break
        @case('Digital Transects')
        @case('My Map')
            <path d="M18 8c0 4-6 9-6 9S6 12 6 8a6 6 0 1 1 12 0Z M5 15l-3 6h20l-3-6"/><circle cx="12" cy="8" r="2"/>
            @break
        @case('Reports & Analytics')
            <path d="M3 21h19 M5 17V9h3v8 M11 17V3h3v14 M17 17v-6h3v6"/>
            @break
        @case('Fieldwork')
            <path d="M12 22V11 M12 15C5 16 3 12 3 7c6 0 9 2 9 8Z M12 11c0-6 3-9 9-9 0 6-3 9-9 9Z"/>
            @break
        @case('Species & Learning')
            <path d="M12 8c-3-2-7-2-10-1v14c3-1 7-1 10 1 3-2 7-2 10-1V7c-3-1-7-1-10 1v14 M12 5c-5 0-6-2-6-4 5 0 6 2 6 4Z M12 5c5 0 6-2 6-4-5 0-6 2-6 4Z"/>
            @break
        @case('AI & System')
            <path d="M20 8a8 8 0 0 0-14-3L3 8 M3 3v5h5 M4 16a8 8 0 0 0 14 3l3-3 M21 21v-5h-5"/>
            @break
        @case('Settings')
            <path d="m9 2-1 3-3 1-3 4 2 2-2 2 3 4 3 1 1 3h6l1-3 3-1 3-4-2-2 2-2-3-4-3-1-1-3H9Z"/><circle cx="12" cy="12" r="4"/>
            @break
    @endswitch
</svg>
