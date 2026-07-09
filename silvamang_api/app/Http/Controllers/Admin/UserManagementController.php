<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class UserManagementController extends Controller
{
    public function index(Request $request)
    {
        $query = User::query()
            ->with('roles')
            ->withCount(['scanRecords', 'assistantLogs'])
            ->when(request('search'), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%");
                });
            })
            ->when(request('role'), fn ($query, $role) => $query->whereHas('roles', fn ($query) => $query->where('name', $role)));

        return view('admin.users.index', [
            'users' => $query->latest()->paginate(10)->withQueryString(),
            'roles' => Role::orderBy('display_name')->get(['name', 'display_name']),
        ]);
    }

    public function create()
    {
        return view('admin.users.create', [
            'user' => new User(),
            'roles' => $this->activeRoles(),
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'roles' => ['nullable', 'array'],
            'roles.*' => ['exists:roles,id'],
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
        ]);

        $roles = $data['roles'] ?? [];

        if (empty($roles)) {
            $mobileUserRole = Role::where('name', 'mobile_user')->first();
            $roles = $mobileUserRole ? [$mobileUserRole->id] : [];
        }

        $user->roles()->sync($roles);

        return redirect()->route('admin.users.index')->with('success', 'User created successfully.');
    }

    public function show(User $user)
    {
        $user->load(['roles'])
            ->loadCount(['scanRecords', 'assistantLogs']);

        $latestScanRecords = $user->scanRecords()->with('species')->latest()->take(5)->get();
        $latestAssistantLogs = $user->assistantLogs()->latest()->take(5)->get();

        return view('admin.users.show', compact('user', 'latestScanRecords', 'latestAssistantLogs'));
    }

    public function edit(User $user)
    {
        $user->load('roles');

        return view('admin.users.edit', [
            'user' => $user,
            'roles' => $this->activeRoles(),
        ]);
    }

    public function update(Request $request, User $user)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
        ]);

        $user->update($data);

        return redirect()->route('admin.users.show', $user)->with('success', 'User updated successfully.');
    }

    public function updateRoles(Request $request, User $user)
    {
        $data = $request->validate([
            'roles' => ['nullable', 'array'],
            'roles.*' => ['exists:roles,id'],
        ]);

        $selectedRoles = $data['roles'] ?? [];
        $currentUser = Auth::user();
        $superAdminRole = Role::where('name', 'super_admin')->first();

        if ($currentUser?->is($user) && empty($selectedRoles)) {
            return back()->with('error', 'You cannot remove all roles from your own account.');
        }

        if (
            $currentUser?->is($user)
            && $superAdminRole
            && $user->roles()->where('name', 'super_admin')->exists()
            && ! in_array((string) $superAdminRole->id, array_map('strval', $selectedRoles), true)
        ) {
            return back()->with('error', 'You cannot remove your own Super Admin role.');
        }

        $user->roles()->sync($selectedRoles);

        return redirect()->route('admin.users.edit', $user)->with('success', 'User roles updated successfully.');
    }

    public function updatePassword(Request $request, User $user)
    {
        $data = $request->validate([
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user->update([
            'password' => Hash::make($data['password']),
        ]);

        return redirect()->route('admin.users.edit', $user)->with('success', 'User password updated successfully.');
    }

    public function destroy(User $user)
    {
        if (Auth::id() === $user->id) {
            return back()->with('error', 'You cannot delete your own account.');
        }

        if ($user->roles()->where('name', 'super_admin')->exists()) {
            $superAdminCount = User::whereHas('roles', fn ($query) => $query->where('name', 'super_admin'))->count();

            if ($superAdminCount <= 1) {
                return back()->with('error', 'You cannot delete the last Super Admin account.');
            }
        }

        $user->delete();

        return redirect()->route('admin.users.index')->with('success', 'User deleted successfully.');
    }

    private function activeRoles()
    {
        return Role::where('status', 'active')->orderBy('display_name')->get();
    }
}
