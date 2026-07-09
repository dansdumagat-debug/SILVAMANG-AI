<?php

use App\Http\Controllers\Api\AiModelController;
use App\Http\Controllers\Api\AiMeasurementController;
use App\Http\Controllers\Api\AiServiceHealthController;
use App\Http\Controllers\Api\AlertController;
use App\Http\Controllers\Api\AssistantLogController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardSummaryController;
use App\Http\Controllers\Api\LocationValidationController;
use App\Http\Controllers\Api\MeasurementController;
use App\Http\Controllers\Api\MockAiPredictionController;
use App\Http\Controllers\Api\PredictionController;
use App\Http\Controllers\Api\ScanImageController;
use App\Http\Controllers\Api\ScanRecordController;
use App\Http\Controllers\Api\SpeciesController;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'app' => 'SILVAMANG AI',
        'message' => 'SILVAMANG AI API is running.',
        'phase' => 'laravel_initialization',
    ]);
});

Route::post('register', [AuthController::class, 'register']);
Route::post('login', [AuthController::class, 'login']);

Route::get('species', [SpeciesController::class, 'index']);
Route::get('species/{species}', [SpeciesController::class, 'show']);
Route::get('predictions', [PredictionController::class, 'index']);
Route::post('predictions', [PredictionController::class, 'store']);
Route::get('predictions/{prediction}', [PredictionController::class, 'show']);

Route::get('measurements', [MeasurementController::class, 'index']);
Route::post('measurements', [MeasurementController::class, 'store']);
Route::get('measurements/{measurement}', [MeasurementController::class, 'show']);

Route::get('location-validations', [LocationValidationController::class, 'index']);
Route::post('location-validations', [LocationValidationController::class, 'store']);
Route::get('location-validations/{locationValidation}', [LocationValidationController::class, 'show']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('logout', [AuthController::class, 'logout']);
    Route::get('me', [AuthController::class, 'me']);
    Route::put('profile', [AuthController::class, 'updateProfile']);
    Route::put('change-password', [AuthController::class, 'changePassword']);

    Route::post('species', [SpeciesController::class, 'store'])->middleware('role:super_admin,admin,researcher');
    Route::put('species/{species}', [SpeciesController::class, 'update'])->middleware('role:super_admin,admin,researcher');
    Route::patch('species/{species}', [SpeciesController::class, 'update'])->middleware('role:super_admin,admin,researcher');
    Route::delete('species/{species}', [SpeciesController::class, 'destroy'])->middleware('role:super_admin,admin,researcher');

    Route::post('scan-records/{scanRecord}/validate-location', [ScanRecordController::class, 'validateLocation']);
    Route::apiResource('scan-records', ScanRecordController::class);
    Route::get('ai/service-health', AiServiceHealthController::class);
    Route::post('ai/mock-predict', MockAiPredictionController::class);
    Route::post('ai/measure', AiMeasurementController::class);
    Route::get('scan-images', [ScanImageController::class, 'index']);
    Route::post('scan-images', [ScanImageController::class, 'store']);
    Route::get('scan-images/{scanImage}', [ScanImageController::class, 'show']);
    Route::delete('scan-images/{scanImage}', [ScanImageController::class, 'destroy']);

    Route::apiResource('ai-models', AiModelController::class)->middleware('role:super_admin,admin');
    Route::apiResource('alerts', AlertController::class)->middleware('role:super_admin,admin,researcher');

    Route::get('assistant-logs', [AssistantLogController::class, 'index']);
    Route::post('assistant-logs', [AssistantLogController::class, 'store']);
    Route::get('assistant-logs/{assistantLog}', [AssistantLogController::class, 'show']);

    Route::get('admin/dashboard-summary', DashboardSummaryController::class)->middleware('role:super_admin,admin,researcher');
});
