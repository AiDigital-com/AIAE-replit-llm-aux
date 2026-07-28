# OpenAI API adapter (opt-in)

Integrates the OpenAI Responses API as an optional external service. The
adapter also supports Chat Completions as an explicit legacy mode.

## Prerequisites

- HTTP client foundation (installed automatically)
- A valid OpenAI API key
- an explicit model ID approved for the target environment

## Install

```bash
PROJECT_ROOT=/path/to/project bash templates/integrations/openai/install.sh
```

## Configuration

Set in `.env.local` (never commit secrets):

```env
OPENAI_ENABLED=true
OPENAI_BASE_URL=https://api.openai.com
OPENAI_API_KEY=sk-...
OPENAI_API_MODE=responses
OPENAI_MODEL=replace-with-approved-model-id
OPENAI_MAX_TOKENS=1024
```

Set `OPENAI_API_MODE=chat-completions` only for an existing integration that
still requires the legacy endpoint.

There is no built-in OpenAI stub. For local development without a real key,
leave the adapter disabled:

```env
OPENAI_ENABLED=false
```

Mock `OpenAiClient` at the consuming service boundary in tests.

## Usage

```java
@Service
public class MyService {
    private final OpenAiClient openAiClient;

    public MyService(OpenAiClient openAiClient) {
        this.openAiClient = openAiClient;
    }

    public String summarize(String text) {
        return openAiClient.complete("Summarize the following text.", text);
    }
}
```

## What is installed

| File | Description |
|------|-------------|
| `OpenAiClient` | Application-facing interface |
| `OpenAiClientImpl` | Production implementation (`/v1/responses` by default; `/v1/chat/completions` in legacy mode) |
| `OpenAiProperties` | Typed `@ConfigurationProperties` |
| `OpenAiConfig` | Registers the client only when `OPENAI_ENABLED=true` and fails fast without a key |
| `OpenAiExternalException` | Runtime exception for HTTP/timeout/parse errors |
| `model/*` | Internal Responses and Chat Completions request/response records |

## Security

- The API key is sent only in the `Authorization: Bearer` header.
- The key is never logged.
- Add `OPENAI_API_KEY` to `.gitignore` patterns and secret scanning rules.
