@extends('admin.layouts.app')
@section('title', 'System Settings')
@section('content')
    <div class="page-heading settings-heading">
        @include('admin.settings.icon', ['icon' => 'settings'])
        <div><h2>System Settings</h2><p>Manage your system preferences, fieldwork options, and account settings.</p></div>
    </div>
    <section class="settings-grid admin-settings settings-workspace" aria-label="System settings">
        <form method="POST" action="{{ route('admin.settings.update') }}" class="form-card">
            @csrf @method('PUT')
            <header class="settings-card-heading">
                @include('admin.settings.icon', ['icon' => 'settings'])
                <div><h3>General Settings</h3><p>Basic system configuration and display preferences.</p></div>
            </header>
            <div class="form-grid">
                <label class="form-group">System name
                    <input name="console_name" value="{{ old('console_name', $preferences['console_name']) }}" maxlength="60" required>
                </label>
                <div class="form-group"><span>Timezone</span><div class="settings-fixed-value">Asia/Manila (UTC+8)</div></div>
                <label class="form-group">Records per page
                    <select name="records_per_page">
                        @foreach ([10, 15, 25, 50, 100] as $size)
                            <option value="{{ $size }}" @selected((int) old('records_per_page', $preferences['records_per_page']) === $size)>{{ $size }} records</option>
                        @endforeach
                    </select>
                    <small>Applies to scans, transects, and users.</small>
                </label>
                <label class="form-group">Support email (optional)
                    <input type="email" name="support_email" value="{{ old('support_email', $preferences['support_email']) }}" maxlength="255" placeholder="help@example.com">
                </label>
            </div>
            <div class="form-actions"><button class="primary-action" type="submit">Save Changes</button></div>
        </form>
        <article class="form-card">
            <header class="settings-card-heading">
                @include('admin.settings.icon', ['icon' => 'map'])
                <div><h3>Transect &amp; Fieldwork Settings</h3><p>Current recording options in the Android app.</p></div>
            </header>
            <dl class="settings-facts">
                <div><dt>Transect naming</dt><dd>Field number and name</dd></div>
                <div><dt>Maximum GPS error for tracking</dt><dd>50 meters</dd></div>
                <div><dt>GPS tracking</dt><dd>Movement-based (1 meter)</dd></div>
                <div><dt>Offline recording</dt><dd>Available</dd></div>
                <div><dt>GPS before saving a scan</dt><dd>Optional</dd></div>
                <div><dt>Manual transect points</dt><dd>Available</dd></div>
            </dl>
            <p class="settings-note">These app options are read-only here. Manage recorded transects and review their locations below.</p>
            <div class="form-actions">
                <a class="secondary-action" href="{{ route('admin.transects.index') }}">Manage Transects</a>
                <a class="secondary-action" href="{{ route('admin.observation-map.index') }}">Observation Map</a>
            </div>
        </article>
        <article class="form-card">
            <header class="settings-card-heading">
                @include('admin.settings.icon', ['icon' => 'ruler'])
                <div><h3>Measurement Settings</h3><p>Review the measurements collected during fieldwork.</p></div>
            </header>
            <ul class="settings-feature-list">
                <li><span class="settings-check" aria-hidden="true">&#10003;</span> Height measurement <span class="settings-unit">meters</span></li>
                <li><span class="settings-check" aria-hidden="true">&#10003;</span> Manual GBH measurement <span class="settings-unit">cm</span></li>
                <li><span class="settings-check" aria-hidden="true">&#10003;</span> Canopy 1 measurement <span class="settings-unit">meters</span></li>
                <li><span class="settings-check" aria-hidden="true">&#10003;</span> Canopy 2 measurement <span class="settings-unit">meters</span></li>
                <li><span class="settings-check" aria-hidden="true">&#10003;</span> Camera estimates for height and canopy</li>
            </ul>
            <p class="settings-note">Measurements are optional. GBH is entered manually; missing measurements remain blank.</p>
            <div class="form-actions"><a class="secondary-action" href="{{ route('admin.measurements.index') }}">Review Measurements</a></div>
        </article>
        <article class="form-card">
            <header class="settings-card-heading">
                @include('admin.settings.icon', ['icon' => 'export'])
                <div><h3>Export Settings</h3><p>Ecological survey workbook and included fields.</p></div>
            </header>
            <div class="settings-inline-value"><strong>Export format</strong><span class="settings-fixed-value">Excel (.xlsx) &middot; Reference workbook</span></div>
            <h4 class="settings-field-label">Included in export</h4>
            <ul class="settings-export-fields">
                @foreach (['Date', 'Recorder', 'Location', 'Transect', 'Plot No.', 'Species', 'Category & Count-MG', 'GBH (cm)', 'Height (m)', 'Canopy 1 & 2 (m)', 'GPS location (Raw Scans)', 'Other observations'] as $field)
                    <li><span class="settings-check" aria-hidden="true">&#10003;</span>{{ $field }}</li>
                @endforeach
            </ul>
            <div class="settings-inline-value"><strong>Empty values</strong><span class="settings-fixed-value">Leave blank</span></div>
            <p class="settings-note">The reference columns and formulas are preserved. Select records and enter the sampled plot area when exporting.</p>
            <div class="form-actions"><a class="primary-action" href="{{ route('admin.transects.export-selection') }}">Select Export Records</a></div>
        </article>
        <form method="POST" action="{{ route('admin.settings.account') }}" class="form-card">
            @csrf @method('PATCH')
            <header class="settings-card-heading">
                @include('admin.settings.icon', ['icon' => 'account'])
                <div><h3>My Account</h3><p>Manage your administrator account.</p></div>
            </header>
            <div class="form-grid">
                <label class="form-group">Name<input name="name" value="{{ old('name', $user->name) }}" maxlength="255" autocomplete="name" required></label>
                <label class="form-group">Email<input type="email" name="email" value="{{ old('email', $user->email) }}" maxlength="255" autocomplete="email" required></label>
                <label class="form-group">Current password<input data-settings-password type="password" name="current_password" autocomplete="current-password" required></label>
            </div>
            <div class="form-actions"><button class="primary-action" type="submit">Save Account Details</button></div>
        </form>
        <form method="POST" action="{{ route('admin.settings.password') }}" class="form-card">
            @csrf @method('PATCH')
            <header class="settings-card-heading">
                @include('admin.settings.icon', ['icon' => 'lock'])
                <div><h3>Change Password</h3><p>Update your account password. Use at least 8 characters.</p></div>
            </header>
            <div class="form-grid">
                <label class="form-group">Current password<input data-settings-password type="password" name="current_password" autocomplete="current-password" required></label>
                <label class="form-group">New password<input data-settings-password type="password" name="password" autocomplete="new-password" minlength="8" required></label>
                <label class="form-group">Confirm new password<input data-settings-password type="password" name="password_confirmation" autocomplete="new-password" minlength="8" required></label>
            </div>
            <div class="form-actions"><button class="primary-action" type="submit">Change Password</button></div>
        </form>
    </section>
    <nav class="settings-footer-links" aria-label="Administration shortcuts">
        <a href="{{ route('admin.users.index') }}">Manage Users &amp; Roles</a>
        <a href="{{ url('/download') }}">App Download Page</a>
        <span data-philippine-clock>{{ now()->timezone('Asia/Manila')->format('M j, Y g:i A') }} PHT</span>
    </nav>
@endsection

@push('scripts')
<script>
    document.querySelectorAll('[data-settings-password]').forEach((input, index) => {
        input.id = `settings-password-${index}`;
        const wrapper = document.createElement('span');
        wrapper.className = 'settings-password-control';
        input.before(wrapper);
        wrapper.append(input);
        const toggle = document.createElement('button');
        toggle.type = 'button';
        toggle.textContent = 'Show';
        toggle.setAttribute('aria-controls', input.id);
        toggle.setAttribute('aria-label', 'Show password');
        toggle.setAttribute('aria-pressed', 'false');
        toggle.addEventListener('click', () => {
            const reveal = input.type === 'password';
            input.type = reveal ? 'text' : 'password';
            toggle.textContent = reveal ? 'Hide' : 'Show';
            toggle.setAttribute('aria-label', reveal ? 'Hide password' : 'Show password');
            toggle.setAttribute('aria-pressed', String(reveal));
        });
        wrapper.append(toggle);
    });
    const timeDisplay = document.querySelector('[data-philippine-clock]');
    const updateTime = () => {
        if (timeDisplay) timeDisplay.textContent = new Intl.DateTimeFormat('en-US', {
            timeZone: 'Asia/Manila', year: 'numeric', month: 'short', day: 'numeric',
            hour: 'numeric', minute: '2-digit',
        }).format(new Date()) + ' PHT';
    };
    updateTime();
    setInterval(updateTime, 30000);
</script>
@endpush
