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
    <script>
        try {
            if (localStorage.getItem('admin-sidebar-collapsed') === 'true') {
                document.body.classList.add('sidebar-collapsed');
            }
        } catch (_) {
            // Navigation remains available when browser storage is disabled.
        }
    </script>
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
        const sidebar = document.getElementById('admin-sidebar');
        const mobileSidebar = window.matchMedia('(max-width: 820px)');
        const sidebarCloseTargets = document.querySelectorAll('[data-sidebar-close], .sidebar-nav a');

        const syncSidebar = () => {
            const isOpen = mobileSidebar.matches
                ? document.body.classList.contains('sidebar-open')
                : !document.body.classList.contains('sidebar-collapsed');
            sidebarToggle?.setAttribute('aria-expanded', String(isOpen));
            sidebarToggle?.setAttribute('aria-label', isOpen ? 'Hide navigation menu' : 'Show navigation menu');
            if (sidebar) {
                sidebar.inert = !isOpen;
                sidebar.setAttribute('aria-hidden', String(!isOpen));
            }
        };

        sidebarToggle?.addEventListener('click', () => {
            if (mobileSidebar.matches) {
                document.body.classList.toggle('sidebar-open');
            } else {
                const isCollapsed = document.body.classList.toggle('sidebar-collapsed');
                try {
                    localStorage.setItem('admin-sidebar-collapsed', String(isCollapsed));
                } catch (_) {
                    // The current page still responds to the toggle.
                }
            }
            syncSidebar();
        });

        sidebarCloseTargets.forEach((target) => {
            target.addEventListener('click', () => {
                if (mobileSidebar.matches) {
                    document.body.classList.remove('sidebar-open');
                    syncSidebar();
                }
            });
        });

        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape' && mobileSidebar.matches && document.body.classList.contains('sidebar-open')) {
                document.body.classList.remove('sidebar-open');
                sidebarToggle?.focus();
                syncSidebar();
            }
        });

        mobileSidebar.addEventListener('change', () => {
            document.body.classList.remove('sidebar-open');
            syncSidebar();
        });

        syncSidebar();
    </script>
    @stack('scripts')
</body>
</html>
