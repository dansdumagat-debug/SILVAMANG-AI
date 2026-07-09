<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

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
            $databaseError = $exception->getMessage();
        }

        return view('admin.settings.index', [
            'systemInfo' => [
                'App Name' => config('app.name'),
                'Environment' => config('app.env'),
                'App URL' => config('app.url'),
                'Laravel Version' => app()->version(),
                'PHP Version' => PHP_VERSION,
                'Timezone' => config('app.timezone'),
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
            'aiConfiguration' => [
                'CNN classifier' => 'planned',
                'YOLOv8 detector' => 'planned',
                'YOLOv8-Seg segmenter' => 'planned',
                'MiDaS depth estimator' => 'planned',
                'Python AI service' => 'not yet integrated',
            ],
            'mobileReadiness' => [
                'Local offline queue' => 'planned in Flutter phase',
                'Cloud synchronization' => 'planned',
                'GPS validation' => 'database/API ready',
            ],
            'buildStatus' => [
                'Laravel initialization' => 'Completed',
                'Database schema' => 'Completed',
                'API structure' => 'Completed',
                'Authentication and roles' => 'Completed',
                'Admin dashboard foundation' => 'Completed',
                'Admin CRUD and review pages' => 'Completed',
                'Reports and analytics' => 'Completed',
                'Flutter mobile app' => 'Pending',
                'Image upload' => 'Pending',
                'AI integration' => 'Pending',
                'Deployment' => 'Pending',
            ],
        ]);
    }
}
