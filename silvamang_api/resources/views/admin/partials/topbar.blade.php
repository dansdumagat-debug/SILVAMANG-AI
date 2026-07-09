@php
    $user = auth()->user();
    $roleLabel = $user?->roles?->pluck('display_name')->join(', ') ?: 'Admin';
@endphp

<header class="admin-topbar">
    <div class="search-box">
        <span class="search-icon"></span>
        <input type="search" placeholder="Search anything...">
    </div>

    <div class="topbar-actions">
        <span class="system-status">AI System Status: Online</span>
        <span class="notification-dot" aria-label="Notifications">1</span>
        <div class="profile-chip">
            <div class="avatar">{{ strtoupper(substr($user?->name ?? 'A', 0, 1)) }}</div>
            <div>
                <strong>{{ $user?->name ?? 'Admin' }}</strong>
                <span>{{ $roleLabel }}</span>
            </div>
        </div>
        <form method="POST" action="{{ route('admin.logout') }}">
            @csrf
            <button type="submit" class="logout-button">Logout</button>
        </form>
    </div>
</header>
