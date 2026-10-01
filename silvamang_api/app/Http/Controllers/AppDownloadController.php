<?php

namespace App\Http\Controllers;

class AppDownloadController extends Controller
{
    public function index()
    {
        $path = storage_path('app/releases/silvamang-ai.apk');
        $available = is_file($path) && is_readable($path) && filesize($path) > 0;

        return response()->view('download', [
            'available' => $available,
            'size' => $available ? number_format(filesize($path) / 1048576, 1) : null,
        ])->header('Cache-Control', 'no-store');
    }

    public function android()
    {
        $path = storage_path('app/releases/silvamang-ai.apk');
        abort_unless(is_file($path) && is_readable($path) && filesize($path) > 0, 404, 'The Android download is not available yet.');

        return response()->download($path, 'silvamang-ai.apk', [
            'Content-Type' => 'application/vnd.android.package-archive',
            'Cache-Control' => 'no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
