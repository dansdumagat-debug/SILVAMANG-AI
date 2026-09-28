<?php

return [
    // Use '*' only when the app is reachable exclusively through a trusted proxy.
    'trusted_proxies' => env('TRUSTED_PROXIES', ''),
    'model_reports_root' => env('MODEL_REPORTS_ROOT', base_path('../silvamang_ai_service/reports/efficientnet_transfer')),
];
