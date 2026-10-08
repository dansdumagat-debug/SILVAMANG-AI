<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;

class SettingController extends Controller
{
    public function index()
    {
        $databaseStatus = 'connected';
        $databaseError = null;

        try {
            DB::connection()->getPdo();
        } catch (\Throwable $exception) {
            $databaseStatus = 'error';
            $databaseError = 'Database connection failed. Check the server logs.';
        }

        // Read-only, bounded probe: a Settings request must never run inference or training.
        $health = [];
        try {
            $response = Http::acceptJson()->connectTimeout(2)->timeout(3)
                ->get(rtrim((string) config('services.ai_service.url'), '/').'/ai/health');
            if ($response->successful() && is_array($response->json())) {
                $health = $response->json();
            }
        } catch (\Throwable) {
            // An unreachable service is reported below, without exposing connection details.
        }
        $online = ($health['service'] ?? null) === 'online'
            && is_array($health['models'] ?? null);
        $aiConfiguration = ['Python AI service' => $online ? 'Connected' : 'Unavailable'];
        foreach (['cnn' => 'CNN classifier', 'yolov8' => 'YOLOv8 detector', 'segmentation' => 'YOLOv8-Seg segmenter'] as $key => $label) {
            $aiConfiguration[$label] = ! $online ? 'Unverified'
                : (data_get($health, "models.$key") === true ? 'Ready' : 'Unavailable');
        }
        $apk = storage_path('app/releases/silvamang-ai.apk');
        $downloadAvailable = is_file($apk) && is_readable($apk) && filesize($apk) > 0;
        $uploadRoute = Route::has('api.scan-images.store');
        // API routes are unnamed in some deployments.
        foreach (Route::getRoutes() as $route) {
            if ($route->uri() === 'api/scan-images' && in_array('POST', $route->methods(), true)) {
                $uploadRoute = true;
            }
        }
        $uploadStorage = Storage::disk('public')->path('');
        $uploadReady = $uploadRoute && is_dir($uploadStorage) && is_writable($uploadStorage);

        return view('admin.settings.index', [
            'checkedAt' => now()->timezone('Asia/Manila')->format('M j, Y g:i:s A').' PHT',
            'systemInfo' => [
                'App Name' => config('app.name'),
                'Environment' => config('app.env'),
                'App URL' => config('app.url'),
                'Laravel Version' => app()->version(),
                'PHP Version' => PHP_VERSION,
                'Server / storage timezone' => config('app.timezone'),
                'Display timezone' => 'Asia/Manila (PHT, UTC+8)',
                'Debug Mode' => config('app.debug') ? 'Enabled' : 'Disabled',
            ],
            'databaseInfo' => [
                'Connection' => config('database.default'),
                'Database Name' => config('database.connections.'.config('database.default').'.database'),
                'Status' => $databaseStatus,
                'Error' => $databaseError,
            ],
            'storageInfo' => [
                'Default Disk' => config('filesystems.default'),
                'Public Storage Path' => public_path('storage'),
                'Storage Link' => is_link(public_path('storage')) || file_exists(public_path('storage')) ? 'linked' : 'missing',
            ],
            'apiGroups' => [
                '/api/species',
                '/api/scan-records',
                '/api/predictions',
                '/api/measurements',
                '/api/location-validations',
                '/api/assistant-logs',
                '/api/ai-models',
                '/api/admin/dashboard-summary',
            ],
            'aiConfiguration' => $aiConfiguration,
            'mobileReadiness' => [
                'Local offline queue' => 'Implemented in the Android app',
                'Cloud synchronization' => 'Implemented; individual records may still need retry',
                'GPS validation' => 'Optional when saving observations',
            ],
            'buildStatus' => [
                'Database connection' => $databaseStatus === 'connected' ? 'Connected' : 'Unavailable',
                'Android APK download' => $downloadAvailable ? 'Available' : 'Missing',
                'Image upload route and storage' => $uploadReady ? 'Ready' : 'Needs attention',
                'AI model readiness' => $online && ! in_array('Unavailable', $aiConfiguration, true) ? 'Ready' : 'Needs attention',
                'Web application' => 'Running',
            ],
        ]);
    }
}
