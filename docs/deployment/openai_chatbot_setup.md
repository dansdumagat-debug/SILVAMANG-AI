# Configure the SILVAMANG OpenAI chatbot

The Flutter app sends chatbot questions to Laravel. Laravel is the only service
that should hold and use the OpenAI API key.

## 1. Revoke an exposed key

If a key was pasted into chat, source code, a screenshot, or another shared
location, revoke it in the OpenAI API dashboard and create a replacement. Do
not test or reuse the exposed value.

## 2. Configure Render

Open the SILVAMANG Laravel API service in Render, select **Environment**, and
add these variables:

```env
AI_PROVIDER=openai
OPENAI_API_KEY=<new replacement project key>
OPENAI_MODEL=gpt-4o-mini
OPENAI_BASE_URL=https://api.openai.com/v1
AI_CHATBOT_TIMEOUT=30
AI_CHATBOT_MAX_OUTPUT_TOKENS=600
AI_CHATBOT_INCLUDE_PRECISE_LOCATION=false
```

`OPENAI_ORGANIZATION` and `OPENAI_PROJECT` are optional. Add them only when the
OpenAI project configuration requires explicit headers. Store the key as a
secret environment value. Do not add it to Flutter, GitHub, `.env.example`, or
the Dockerfile.

Save the Render environment changes and allow the Laravel service to redeploy.
The startup script rebuilds Laravel's configuration cache, so the new server
environment is loaded during boot.

## 3. Verify configuration without revealing the key

In Render Shell, this command reports whether a key exists without printing it:

```sh
php artisan tinker --execute="dump(config('services.ai_chatbot.provider'), filled(config('services.ai_chatbot.openai_api_key')), config('services.ai_chatbot.openai_model'), config('services.ai_chatbot.openai_base_url'));"
```

Expected values are `openai`, `true`, the configured model, and
`https://api.openai.com/v1`.

The API request explicitly sets `store: false`, limits response length, and
does not add exact GPS coordinates or manual location notes to its generated
scan context unless `AI_CHATBOT_INCLUDE_PRECISE_LOCATION=true` is set
intentionally. Any caller-supplied context must follow the same privacy rule.

Sign in to SILVAMANG, open **Chatbot Management** or the mobile AI Assistant,
and submit a simple mangrove question. A successful external response has
`source: ai_api` and `provider: openai`. If OpenAI is unavailable, the existing
verified knowledge and offline fallback remain available.

## 4. Troubleshooting

- `401`: replace the key and confirm it belongs to the intended OpenAI project.
- `429`: check project billing, credits, rate limits, and usage limits.
- Local response instead of `ai_api`: inspect Render logs for the HTTP status
  and OpenAI request ID. The application does not log the API key.
- Configuration still looks old: redeploy the API or run
  `php artisan config:clear && php artisan config:cache` in Render Shell.

Rotate the key periodically and immediately after any accidental disclosure.
