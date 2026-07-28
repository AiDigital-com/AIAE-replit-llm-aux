# Claude API adapter (opt-in)

Integrates the Anthropic Claude API as an optional external service.

## Prerequisites

- HTTP client foundation (installed automatically)
- A valid Anthropic API key
- an explicit model ID approved for the target environment

## Install

```bash
PROJECT_ROOT=/path/to/project bash templates/integrations/claude/install.sh
```

## Configuration

Set in `.env.local` (never commit secrets):

```env
CLAUDE_ENABLED=true
CLAUDE_BASE_URL=https://api.anthropic.com
CLAUDE_API_KEY=sk-ant-...
CLAUDE_API_VERSION=2023-06-01
CLAUDE_MODEL=replace-with-approved-model-id
CLAUDE_MAX_TOKENS=1024
```

There is no built-in Claude stub. For local development without a real key,
leave the adapter disabled:

```env
CLAUDE_ENABLED=false
```

Mock `ClaudeClient` at the consuming service boundary in tests.

## Usage

Inject `ClaudeClient` into any Spring-managed service:

```java
@Service
public class MyService {
    private final ClaudeClient claudeClient;

    public MyService(ClaudeClient claudeClient) {
        this.claudeClient = claudeClient;
    }

    public String summarize(String text) {
        return claudeClient.complete("Summarize the following text concisely.", text);
    }
}
```

## What is installed

| File | Description |
|------|-------------|
| `ClaudeClient` | Application-facing interface |
| `ClaudeClientImpl` | Production implementation (POST `/v1/messages`) |
| `ClaudeProperties` | Typed `@ConfigurationProperties` |
| `ClaudeConfig` | Registers the client only when `CLAUDE_ENABLED=true` and fails fast without a key |
| `ClaudeExternalException` | Runtime exception for HTTP/timeout/parse errors |
| `model/*` | Internal request/response records |

## Security

- The API key is never logged.
- Request/response bodies are never logged by default.
- Add `CLAUDE_API_KEY` to `.gitignore` patterns and secret scanning rules.
