<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Admin Console') - SILVAMANG AI</title>
    <link rel="stylesheet" href="{{ asset('css/admin.css') }}">
</head>
<body>
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
</body>
</html>
