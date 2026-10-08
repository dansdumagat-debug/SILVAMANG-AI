@extends('admin.layouts.app')
@section('title', 'Settings')
@section('content')
    <div class="page-heading"><div><h2>System Settings</h2><p>Manage your admin workspace, account, and security.</p></div></div>
    <section class="settings-grid">
        <form method="POST" action="{{ route('admin.settings.update') }}" class="form-card">
            @csrf @method('PUT')
            <h3>General Preferences</h3>
            <p>These preferences apply to all administrators using the website.</p>
            <div class="form-grid">
                <label class="form-group">Admin console name
                    <input name="console_name" value="{{ old('console_name', $preferences['console_name']) }}" maxlength="60" required>
                </label>
                <label class="form-group">Support email (optional)
                    <input type="email" name="support_email" value="{{ old('support_email', $preferences['support_email']) }}" maxlength="255">
                    <small>Shown as a help contact below admin pages.</small>
                </label>
                <label class="form-group">Records per page
                    <select name="records_per_page">
                        @foreach ([10, 15, 25, 50, 100] as $size)
                            <option value="{{ $size }}" @selected((int) old('records_per_page', $preferences['records_per_page']) === $size)>{{ $size }} records</option>
                        @endforeach
                    </select>
                    <small>Applies to Mangrove Scans, Digital Transects, and Users.</small>
                </label>
            </div>
            <div class="form-actions"><button class="primary-action" type="submit">Save System Preferences</button></div>
        </form>
        <article class="form-card">
            <h3>Administration</h3>
            <p>Manage access and share the latest Android app.</p>
            <div class="form-actions">
                <a class="secondary-action" href="{{ route('admin.users.index') }}">Manage Users &amp; Roles</a>
                <a class="secondary-action" href="{{ url('/download') }}">App Download Page</a>
            </div>
            <div class="system-info-row"><span>Local time</span><strong>{{ now()->timezone('Asia/Manila')->format('M j, Y g:i A') }} PHT</strong></div>
            <p>Philippine time (UTC+8) is used for local display. Existing observation times remain unchanged.</p>
        </article>
        <form method="POST" action="{{ route('admin.settings.account') }}" class="form-card">
            @csrf @method('PATCH')
            <h3>My Account</h3>
            <div class="form-grid">
                <label class="form-group">Name<input name="name" value="{{ old('name', $user->name) }}" maxlength="255" autocomplete="name" required></label>
                <label class="form-group">Email<input type="email" name="email" value="{{ old('email', $user->email) }}" maxlength="255" autocomplete="email" required></label>
                <label class="form-group">Current password<input type="password" name="current_password" autocomplete="current-password" required></label>
            </div>
            <div class="form-actions"><button class="primary-action" type="submit">Save Account Details</button></div>
        </form>
        <form method="POST" action="{{ route('admin.settings.password') }}" class="form-card">
            @csrf @method('PATCH')
            <h3>Change Password</h3>
            <p>Use at least 8 characters. Your current password is required.</p>
            <div class="form-grid">
                <label class="form-group">Current password<input type="password" name="current_password" autocomplete="current-password" required></label>
                <label class="form-group">New password<input type="password" name="password" autocomplete="new-password" minlength="8" required></label>
                <label class="form-group">Confirm new password<input type="password" name="password_confirmation" autocomplete="new-password" minlength="8" required></label>
            </div>
            <div class="form-actions"><button class="primary-action" type="submit">Change Password</button></div>
        </form>
    </section>
@endsection
