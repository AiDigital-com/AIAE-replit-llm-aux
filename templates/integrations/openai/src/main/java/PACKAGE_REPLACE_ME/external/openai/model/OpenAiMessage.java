package PACKAGE_REPLACE_ME.external.openai.model;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * A single message in an OpenAI Chat Completions request or response.
 *
 * <p>Internal to the adapter — not exposed outside the external-services module.
 *
 * @param role    message role: {@code "system"}, {@code "user"}, or {@code "assistant"}
 * @param content message text
 */
public record OpenAiMessage(
        @JsonProperty("role") String role,
        @JsonProperty("content") String content) {
}
