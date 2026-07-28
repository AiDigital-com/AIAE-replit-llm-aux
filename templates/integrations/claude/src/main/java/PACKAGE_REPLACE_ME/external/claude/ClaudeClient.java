package PACKAGE_REPLACE_ME.external.claude;

/**
 * Narrow application-facing interface for the Anthropic Claude API.
 *
 * <p>Callers submit a system prompt and a user message; the implementation
 * handles authentication, request serialization, and response extraction.
 * Vendor types are never exposed through this interface.
 *
 * <p>Non-2xx responses, timeouts, and malformed responses are mapped to
 * {@link ClaudeExternalException}.
 */
public interface ClaudeClient {

    /**
     * Sends a single-turn completion request to Claude.
     *
     * @param systemPrompt instruction context for the model (may be blank)
     * @param userMessage  user-facing prompt text
     * @return the model's text response
     * @throws ClaudeExternalException on any HTTP, timeout, or parse failure
     */
    String complete(String systemPrompt, String userMessage);
}
