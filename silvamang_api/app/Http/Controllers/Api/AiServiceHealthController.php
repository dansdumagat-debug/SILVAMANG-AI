<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PythonAiService;

class AiServiceHealthController extends Controller
{
    public function __invoke(PythonAiService $pythonAiService)
    {
        $health = $pythonAiService->health();

        return response()->json([
            'message' => $health['available']
                ? 'AI service health checked successfully.'
                : 'AI service is currently unavailable.',
            'data' => $health,
        ]);
    }
}
