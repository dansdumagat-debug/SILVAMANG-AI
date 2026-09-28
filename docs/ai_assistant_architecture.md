# SILVAMANG AI Assistant Architecture

## Purpose

The SILVAMANG AI Assistant is a hybrid educational chatbot for students, researchers, environmental workers, and mangrove field users. It grounds configured external AI responses with verified local knowledge and falls back to direct local answers when the provider is unavailable.

## Hybrid workflow

1. The user asks a question from the Flutter AI Assistant.
2. Flutter sends the message to Laravel through `/api/chatbot/message`.
3. Laravel searches the `mangrove_knowledge` table and builds authorized field context.
4. If an external provider is configured, Laravel sends the question with relevant verified context.
5. If the provider is unavailable, Laravel returns a verified knowledge entry or a local rule based answer.

The existing `/api/ai/assistant/chat` endpoint is kept for compatibility.

## Offline processing

Flutter still has local fallback assistant responses for basic mangrove guidance when the Laravel API cannot be reached. The Laravel backend also avoids fabricating answers: if the verified knowledge base does not contain a matching entry and no AI API response is available, it returns:

`No verified information is available offline.`

## Online AI enhancement

The external AI provider is optional and replaceable. Configure it in `.env`:

```env
AI_PROVIDER=openai
OPENAI_API_KEY=<set this only in the server environment>
OPENAI_MODEL=gpt-4o-mini
OPENAI_BASE_URL=https://api.openai.com/v1
AI_CHATBOT_TIMEOUT=30
AI_CHATBOT_MAX_OUTPUT_TOKENS=600
AI_CHATBOT_INCLUDE_PRECISE_LOCATION=false
```

OpenRouter or another OpenAI-compatible provider can use `AI_API_URL`,
`AI_MODEL`, and `AI_API_KEY` with the matching `AI_PROVIDER` value. Official
OpenAI and compatible-provider settings are resolved separately, and Gemini
uses only `GEMINI_API_KEY`.

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

API keys must stay in the Laravel or Render server environment and must not be
hardcoded in source code, committed `.env` files, or Flutter assets. Laravel
uses the authenticated API user when logging assistant interactions. External
AI calls should not include passwords, tokens, or sensitive user data. Exact
GPS coordinates and manual location notes are excluded from automatically
built scan context by default. Caller-supplied context must follow the same
privacy rule. External context is passed as untrusted user-level reference
data, and OpenAI requests explicitly disable response storage.

## Limitations

- The assistant only returns verified offline answers when knowledge records exist.
- External AI responses depend on internet connectivity and provider configuration.
- Local Flutter fallback is limited to basic mangrove education and should be expanded with verified content over time.
- The chatbot does not change CNN, YOLOv8, MiDaS, ONNX, or image inference behavior.
