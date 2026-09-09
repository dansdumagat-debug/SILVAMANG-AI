<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'mailgun' => [
        'domain' => env('MAILGUN_DOMAIN'),
        'secret' => env('MAILGUN_SECRET'),
        'endpoint' => env('MAILGUN_ENDPOINT', 'api.mailgun.net'),
        'scheme' => 'https',
    ],

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'ai_service' => [
        'url' => env('AI_SERVICE_URL', 'http://127.0.0.1:9000'),
        'timeout' => env('AI_SERVICE_TIMEOUT', 30),
        'mode' => env('AI_SERVICE_MODE', 'mock'),
    ],

    'ai_chatbot' => [
        'provider' => env('AI_PROVIDER', 'auto'),
        'api_key' => env('AI_API_KEY'),
        'model' => env('AI_MODEL', 'gpt-4o-mini'),
        'base_url' => env('AI_API_URL', env('AI_API_BASE_URL', env('OPENAI_BASE_URL', 'https://api.openai.com/v1'))),
        'gemini_api_key' => env('GEMINI_API_KEY', env('AI_API_KEY')),
        'gemini_model' => env('GEMINI_MODEL', env('AI_MODEL', 'gemini-1.5-flash')),
        'gemini_url' => env('GEMINI_API_URL', 'https://generativelanguage.googleapis.com/v1beta'),
        'ollama_url' => env('OLLAMA_API_URL', 'http://127.0.0.1:11434'),
        'ollama_model' => env('OLLAMA_MODEL', 'llama3.2'),
        'timeout' => env('AI_CHATBOT_TIMEOUT', 30),
    ],

    'inaturalist' => [
        'base_url' => env('INATURALIST_API_URL', 'https://api.inaturalist.org/v1'),
        'timeout' => env('INATURALIST_TIMEOUT', 15),
        'per_page' => env('INATURALIST_PER_PAGE', 8),
    ],

];
