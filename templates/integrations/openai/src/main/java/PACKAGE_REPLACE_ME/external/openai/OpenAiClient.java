package PACKAGE_REPLACE_ME.external.openai;

/**
 * Narrow application-facing interface for the OpenAI Chat Completions API.
 *
 * <p>Callers submit a system prompt and a user message; the implementation
 * handles authentication, request serialization, and response extraction.
 * Vendor types are never exposed through this interface.
 *
 * <p>Non-2xx responses, timeouts, and malformed responses are mapped to
 * {@link OpenAiExternalException}.
 */
public interface OpenAiClient {

    /**
     * Sends a single-turn chat completion request to the OpenAI API.
     *
     * @param systemPrompt instruction context for the model (may be blank)
     * @param userMessage  user-facing prompt text
     * @return the model's text response
     * @throws OpenAiExternalException on any HTTP, timeout, or parse failure
     */
    String complete(String systemPrompt, String userMessage);
}
