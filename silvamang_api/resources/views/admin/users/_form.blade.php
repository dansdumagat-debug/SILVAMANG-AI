@php
    $isCreate = $mode === 'create';
    $selectedRoles = collect(old('roles', $user->exists ? $user->roles->pluck('id')->all() : []))->map(fn ($id) => (string) $id)->all();
@endphp

<div class="form-grid">
    <label class="form-group">
        Name
        <input type="text" name="name" value="{{ old('name', $user->name) }}" required>
    </label>
    <label class="form-group">
        Email
        <input type="email" name="email" value="{{ old('email', $user->email) }}" required>
    </label>

    @if ($isCreate)
        <label class="form-group">
            Password
            <input type="password" name="password" required>
        </label>
        <label class="form-group">
            Confirm Password
            <input type="password" name="password_confirmation" required>
        </label>
        <div class="form-group full">
            <span>Roles</span>
            <div class="checkbox-group">
                @foreach ($roles as $role)
                    <label>
                        <input type="checkbox" name="roles[]" value="{{ $role->id }}" @checked(in_array((string) $role->id, $selectedRoles, true))>
                        <span>{{ $role->display_name }}</span>
                    </label>
                @endforeach
            </div>
            <small class="muted-text">If no role is selected, mobile_user will be assigned when available.</small>
        </div>
    @endif
</div>
