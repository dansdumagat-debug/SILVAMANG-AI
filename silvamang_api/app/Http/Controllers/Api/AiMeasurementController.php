<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;

class AiMeasurementController extends Controller
{
    public function __invoke()
    {
        return response()->json([
            'message' => 'Automatic depth measurement has been removed. Enter manual field measurements or use reference-object calibration.',
            'data' => null,
        ], 410);
    }
}
