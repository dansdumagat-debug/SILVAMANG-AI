@if (session('success'))
    <div class="flash-alert flash-success">{{ session('success') }}</div>
@endif

@if (session('error'))
    <div class="flash-alert flash-error">{{ session('error') }}</div>
@endif

@if ($errors->any())
    <div class="flash-alert flash-error">
        <strong>Please review the form errors.</strong>
        <ul>
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    </div>
@endif
