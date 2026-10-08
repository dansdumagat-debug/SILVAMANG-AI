<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class SettingController extends Controller
{
    public static function preferences(): array
    {
        $defaults = ['console_name' => 'SILVAMANG AI', 'support_email' => '', 'records_per_page' => 15, 'gps_max_error_m' => 50, 'gps_distance_m' => 1];
        if (! Schema::hasTable('system_settings')) {
            return $defaults;
        }
        return array_replace($defaults, DB::table('system_settings')->whereIn('key', array_keys($defaults))->pluck('value', 'key')->all());
    }

    public function index(Request $request)
    {
        return view('admin.settings.index', ['preferences' => self::preferences(), 'user' => $request->user()]);
    }

    public function update(Request $request)
    {
        $data = $request->validate([
            'console_name' => ['required', 'string', 'max:60'],
            'support_email' => ['nullable', 'email', 'max:255'],
            'records_per_page' => ['required', 'integer', Rule::in([10, 15, 25, 50, 100])],
        ]);
        DB::transaction(function () use ($data, $request) {
            foreach ($data as $key => $value) {
                DB::table('system_settings')->updateOrInsert(['key' => $key], [
                    'value' => (string) $value, 'updated_by' => $request->user()->id, 'updated_at' => now(),
                ]);
            }
        });
        return back()->with('success', 'System preferences saved.');
    }

    public function fieldwork(Request $request)
    {
        $data = $request->validate([
            'gps_max_error_m' => ['required', 'integer', Rule::in([10, 15, 25, 50])],
            'gps_distance_m' => ['required', 'integer', Rule::in([1, 2, 5, 10])],
        ]);
        DB::transaction(function () use ($data, $request) {
            foreach ($data as $key => $value) {
                DB::table('system_settings')->updateOrInsert(['key' => $key], [
                    'value' => (string) $value, 'updated_by' => $request->user()->id, 'updated_at' => now(),
                ]);
            }
        });
        return back()->with('success', 'Fieldwork settings saved. Updated apps apply them when opening a new transect.');
    }

    public function account(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users')->ignore($request->user()->id)],
            'current_password' => ['required', 'current_password:web'],
        ]);
        $user = $request->user();
        if ($data['email'] !== $user->email) {
            $user->email_verified_at = null;
        }
        $user->fill(['name' => $data['name'], 'email' => $data['email']])->save();
        return back()->with('success', 'Your account details have been updated.');
    }

    public function password(Request $request)
    {
        $data = $request->validate([
            'current_password' => ['required', 'current_password:web'],
            'password' => ['required', 'confirmed', Password::min(8), 'different:current_password'],
        ]);
        $request->user()->update(['password' => $data['password']]);
        $request->session()->regenerate();
        return back()->with('success', 'Your password has been changed.');
    }
}
