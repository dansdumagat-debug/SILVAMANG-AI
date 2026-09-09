<?php

use App\Http\Controllers\Admin\AiModelController;
use App\Http\Controllers\Admin\AlertController;
use App\Http\Controllers\Admin\AssistantLogController;
use App\Http\Controllers\Admin\ChatbotManagementController;
use App\Http\Controllers\Admin\DatasetVerificationController;
use App\Http\Controllers\Admin\ExternalSpeciesObservationController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\LocationValidationController;
use App\Http\Controllers\Admin\MangroveEducationController;
use App\Http\Controllers\Admin\MangroveKnowledgeController;
use App\Http\Controllers\Admin\MeasurementController;
use App\Http\Controllers\Admin\ObservationMapController;
use App\Http\Controllers\Admin\ReportController;
use App\Http\Controllers\Admin\ScanRecordController;
use App\Http\Controllers\Admin\SettingController;
use App\Http\Controllers\Admin\SpeciesManagementController;
use App\Http\Controllers\Admin\UserManagementController;
use App\Http\Controllers\Api\AssistantChatController as ApiAssistantChatController;
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

Route::redirect('/home', '/admin/dashboard')->middleware('auth');

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

    if (! $request->user()?->hasAnyRole(['super_admin', 'admin', 'researcher'])) {
        return redirect()->route('admin.dashboard');
    }

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
    ->middleware(['web', 'auth'])
    ->group(function () {
        Route::get('/dashboard', DashboardController::class)->name('dashboard');
        Route::middleware('role:super_admin,admin,researcher')->group(function () {
        Route::get('/species', [SpeciesManagementController::class, 'index'])->name('species.index');
        Route::get('/species/create', [SpeciesManagementController::class, 'create'])->name('species.create');
        Route::post('/species', [SpeciesManagementController::class, 'store'])->name('species.store');
        Route::get('/species/{species}', [SpeciesManagementController::class, 'show'])->name('species.show');
        Route::get('/species/{species}/edit', [SpeciesManagementController::class, 'edit'])->name('species.edit');
        Route::put('/species/{species}', [SpeciesManagementController::class, 'update'])->name('species.update');
        Route::delete('/species/{species}', [SpeciesManagementController::class, 'destroy'])
            ->middleware('role:super_admin,admin')
            ->name('species.destroy');
        Route::get('/scan-monitoring', [ScanRecordController::class, 'index'])->name('scan-monitoring.index');
        Route::get('/scan-records', [ScanRecordController::class, 'index'])->name('scan-records.index');
        Route::get('/scan-monitoring/{scanRecord}', [ScanRecordController::class, 'show'])->name('scan-monitoring.show');
        Route::get('/scan-records/{scanRecord}', [ScanRecordController::class, 'show'])->name('scan-records.show');
        Route::get('/dataset-verification', [DatasetVerificationController::class, 'index'])->name('dataset-verification.index');
        Route::get('/dataset-verification/{scanImage}', [DatasetVerificationController::class, 'show'])->name('dataset-verification.show');
        Route::patch('/dataset-verification/{scanImage}', [DatasetVerificationController::class, 'update'])->name('dataset-verification.update');
        Route::post('/dataset-verification/export', [DatasetVerificationController::class, 'exportVerified'])->name('dataset-verification.export');
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
        Route::middleware('role:super_admin,admin')->group(function () {
            Route::get('/chatbot-management', ChatbotManagementController::class)->name('chatbot-management.index');
            Route::post('/chatbot-management/message', ApiAssistantChatController::class)->name('chatbot-management.message');
            Route::patch('/chatbot-management/unanswered/{unansweredQuestion}/resolve', [ChatbotManagementController::class, 'resolveUnanswered'])->name('chatbot-management.unanswered.resolve');
            Route::get('/mangrove-knowledge', [MangroveKnowledgeController::class, 'index'])->name('mangrove-knowledge.index');
            Route::get('/mangrove-knowledge/create', [MangroveKnowledgeController::class, 'create'])->name('mangrove-knowledge.create');
            Route::post('/mangrove-knowledge', [MangroveKnowledgeController::class, 'store'])->name('mangrove-knowledge.store');
            Route::get('/mangrove-knowledge/{mangroveKnowledge}/edit', [MangroveKnowledgeController::class, 'edit'])->name('mangrove-knowledge.edit');
            Route::put('/mangrove-knowledge/{mangroveKnowledge}', [MangroveKnowledgeController::class, 'update'])->name('mangrove-knowledge.update');
            Route::delete('/mangrove-knowledge/{mangroveKnowledge}', [MangroveKnowledgeController::class, 'destroy'])->name('mangrove-knowledge.destroy');
            Route::get('/mangrove-education', [MangroveEducationController::class, 'index'])->name('mangrove-education.index');
            Route::get('/mangrove-education/create', [MangroveEducationController::class, 'create'])->name('mangrove-education.create');
            Route::post('/mangrove-education', [MangroveEducationController::class, 'store'])->name('mangrove-education.store');
            Route::get('/mangrove-education/{mangroveEducation}/edit', [MangroveEducationController::class, 'edit'])->name('mangrove-education.edit');
            Route::put('/mangrove-education/{mangroveEducation}', [MangroveEducationController::class, 'update'])->name('mangrove-education.update');
            Route::delete('/mangrove-education/{mangroveEducation}', [MangroveEducationController::class, 'destroy'])->name('mangrove-education.destroy');
            Route::get('/external-biodiversity', [ExternalSpeciesObservationController::class, 'index'])->name('external-biodiversity.index');
            Route::post('/external-biodiversity/refresh', [ExternalSpeciesObservationController::class, 'refresh'])->name('external-biodiversity.refresh');
            Route::delete('/external-biodiversity/clear', [ExternalSpeciesObservationController::class, 'clear'])->name('external-biodiversity.clear');
        });
        Route::get('/observation-map', ObservationMapController::class)->name('observation-map.index');
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
        });
        Route::get('/settings', [SettingController::class, 'index'])->name('settings.index');
    });
