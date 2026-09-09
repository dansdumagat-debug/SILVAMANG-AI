# SILVAMANG AI Assistant Architecture

## Purpose

The SILVAMANG AI Assistant is a hybrid educational chatbot for students, researchers, environmental workers, and mangrove field users. It answers mangrove questions using verified local knowledge first, then optionally uses an OpenAI-compatible API when configured and available.

## Hybrid workflow

1. The user asks a question from the Flutter AI Assistant.
2. Flutter sends the message to Laravel through `/api/chatbot/message`.
3. Laravel searches the `mangrove_knowledge` table.
4. If a verified answer is found, Laravel returns it with `source: knowledge_base`.
5. If no verified answer is found and an external AI API is configured, Laravel calls the configured OpenAI-compatible chat endpoint.
6. If neither local knowledge nor the external API is available, Laravel returns `source: offline` with a clear unavailable message.

The existing `/api/ai/assistant/chat` endpoint is kept for compatibility.

## Offline processing

Flutter still has local fallback assistant responses for basic mangrove guidance when the Laravel API cannot be reached. The Laravel backend also avoids fabricating answers: if the verified knowledge base does not contain a matching entry and no AI API response is available, it returns:

`No verified information is available offline.`

## Online AI enhancement

The external AI provider is optional and replaceable. Configure it in `.env`:

```env
AI_PROVIDER=openai
AI_API_KEY=
AI_MODEL=gpt-4o-mini
AI_API_BASE_URL=https://api.openai.com/v1
AI_CHATBOT_TIMEOUT=30
```

OpenRouter or other OpenAI-compatible providers can be used by changing `AI_API_BASE_URL`, `AI_MODEL`, and `AI_API_KEY`.

## Knowledge database

Verified content is stored in `mangrove_knowledge`.

Fields:

- `category`
- `question`
- `answer`
- `species_name`
- `keywords`

Supported categories include species information, habitat, distribution, conservation, ecology, measurement, location, and field guidance.

Admins can manage this content from the Laravel admin page:

`Admin > Mangrove Knowledge`

## Species result integration

The Identification Result page includes an `Ask AI Assistant` action. It opens the assistant with species context such as:

`The identified species is Rhizophora apiculata. Explain its habitat, ecological importance, and conservation value.`

## Logging

Assistant interactions are stored in the existing `assistant_logs` table and the new `chatbot_logs` table. Logs include user, scan record, question, response, intent, source, and timestamp.

Source values:

- `knowledge_base`
- `ai_api`
- `offline`

## Security considerations

API keys must stay in `.env` and must not be hardcoded in code or Flutter assets. Laravel uses the authenticated API user when logging assistant interactions. External AI calls should not include passwords, tokens, or sensitive user data.

## Limitations

- The assistant only returns verified offline answers when knowledge records exist.
- External AI responses depend on internet connectivity and provider configuration.
- Local Flutter fallback is limited to basic mangrove education and should be expanded with verified content over time.
- The chatbot does not change CNN, YOLOv8, MiDaS, ONNX, or image inference behavior.
