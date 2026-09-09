<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Admin Console') - SILVAMANG AI</title>
    <link rel="stylesheet" href="{{ asset('css/admin.css') }}">
    @stack('styles')
</head>
<body>
    <div class="mobile-sidebar-backdrop" data-sidebar-close></div>
    <div class="admin-shell">
        @include('admin.partials.sidebar')

        <main class="admin-main">
            @include('admin.partials.topbar')

            <section class="admin-content">
                @include('admin.partials.flash')
                @yield('content')
            </section>
        </main>
    </div>
    <script>
        const sidebarToggle = document.querySelector('[data-sidebar-toggle]');
        const sidebarCloseTargets = document.querySelectorAll('[data-sidebar-close], .sidebar-nav a');

        sidebarToggle?.addEventListener('click', () => {
            const isOpen = document.body.classList.toggle('sidebar-open');
            sidebarToggle.setAttribute('aria-expanded', String(isOpen));
        });

        sidebarCloseTargets.forEach((target) => {
            target.addEventListener('click', () => {
                document.body.classList.remove('sidebar-open');
                sidebarToggle?.setAttribute('aria-expanded', 'false');
            });
        });
    </script>
    @stack('scripts')
</body>
</html>
