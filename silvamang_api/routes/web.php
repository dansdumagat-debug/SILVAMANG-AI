<?php

use App\Http\Controllers\Admin\AiModelController;
use App\Http\Controllers\Admin\AlertController;
use App\Http\Controllers\Admin\AssistantLogController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\LocationValidationController;
use App\Http\Controllers\Admin\MeasurementController;
use App\Http\Controllers\Admin\ReportController;
use App\Http\Controllers\Admin\ScanRecordController;
use App\Http\Controllers\Admin\SettingController;
use App\Http\Controllers\Admin\SpeciesManagementController;
use App\Http\Controllers\Admin\UserManagementController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "web" middleware group. Make something great!
|
*/

Route::get('/', function () {
    return view('landing');
});

Route::get('/login', function () {
    return view('auth.login');
})->middleware('guest')->name('login');

Route::post('/login', function (Request $request) {
    $credentials = $request->validate([
        'email' => ['required', 'email'],
        'password' => ['required', 'string'],
    ]);

    if (! Auth::attempt($credentials, $request->boolean('remember'))) {
        return back()->withErrors([
            'email' => 'The provided credentials do not match our records.',
        ])->onlyInput('email');
    }

    $request->session()->regenerate();

    return redirect()->intended(route('admin.dashboard'));
})->middleware('guest')->name('login.store');

Route::post('/admin/logout', function (Request $request) {
    Auth::logout();
    $request->session()->invalidate();
    $request->session()->regenerateToken();

    return redirect()->route('login');
})->middleware('auth')->name('admin.logout');

Route::prefix('admin')
    ->name('admin.')
    ->middleware(['web', 'auth', 'role:super_admin,admin,researcher'])
    ->group(function () {
        Route::get('/dashboard', DashboardController::class)->name('dashboard');
        Route::get('/species', [SpeciesManagementController::class, 'index'])->name('species.index');
        Route::get('/species/create', [SpeciesManagementController::class, 'create'])->name('species.create');
        Route::post('/species', [SpeciesManagementController::class, 'store'])->name('species.store');
        Route::get('/species/{species}', [SpeciesManagementController::class, 'show'])->name('species.show');
        Route::get('/species/{species}/edit', [SpeciesManagementController::class, 'edit'])->name('species.edit');
        Route::put('/species/{species}', [SpeciesManagementController::class, 'update'])->name('species.update');
        Route::delete('/species/{species}', [SpeciesManagementController::class, 'destroy'])
            ->middleware('role:super_admin,admin')
            ->name('species.destroy');
        Route::get('/scan-records', [ScanRecordController::class, 'index'])->name('scan-records.index');
        Route::get('/scan-records/{scanRecord}', [ScanRecordController::class, 'show'])->name('scan-records.show');
        Route::get('/measurements', [MeasurementController::class, 'index'])->name('measurements.index');
        Route::get('/measurements/{measurement}', [MeasurementController::class, 'show'])->name('measurements.show');
        Route::get('/location-validations', [LocationValidationController::class, 'index'])->name('location-validations.index');
        Route::get('/location-validations/{locationValidation}', [LocationValidationController::class, 'show'])->name('location-validations.show');
        Route::get('/ai-models', [AiModelController::class, 'index'])->name('ai-models.index');
        Route::get('/ai-models/create', [AiModelController::class, 'create'])->name('ai-models.create');
        Route::post('/ai-models', [AiModelController::class, 'store'])->name('ai-models.store');
        Route::get('/ai-models/{aiModel}', [AiModelController::class, 'show'])->name('ai-models.show');
        Route::get('/ai-models/{aiModel}/edit', [AiModelController::class, 'edit'])->name('ai-models.edit');
        Route::put('/ai-models/{aiModel}', [AiModelController::class, 'update'])->name('ai-models.update');
        Route::delete('/ai-models/{aiModel}', [AiModelController::class, 'destroy'])->name('ai-models.destroy');
        Route::get('/assistant-logs', [AssistantLogController::class, 'index'])->name('assistant-logs.index');
        Route::get('/assistant-logs/{assistantLog}', [AssistantLogController::class, 'show'])->name('assistant-logs.show');
        Route::get('/alerts', [AlertController::class, 'index'])->name('alerts.index');
        Route::get('/alerts/{alert}', [AlertController::class, 'show'])->name('alerts.show');
        Route::patch('/alerts/{alert}/status', [AlertController::class, 'updateStatus'])->name('alerts.update-status');
        Route::get('/reports', [ReportController::class, 'index'])->name('reports.index');
        Route::middleware('role:super_admin,admin')->group(function () {
            Route::get('/users', [UserManagementController::class, 'index'])->name('users.index');
            Route::get('/users/create', [UserManagementController::class, 'create'])->name('users.create');
            Route::post('/users', [UserManagementController::class, 'store'])->name('users.store');
            Route::get('/users/{user}', [UserManagementController::class, 'show'])->name('users.show');
            Route::get('/users/{user}/edit', [UserManagementController::class, 'edit'])->name('users.edit');
            Route::put('/users/{user}', [UserManagementController::class, 'update'])->name('users.update');
            Route::delete('/users/{user}', [UserManagementController::class, 'destroy'])->name('users.destroy');
            Route::patch('/users/{user}/roles', [UserManagementController::class, 'updateRoles'])->name('users.update-roles');
            Route::patch('/users/{user}/password', [UserManagementController::class, 'updatePassword'])->name('users.update-password');
        });
        Route::get('/settings', [SettingController::class, 'index'])->name('settings.index');
    });
