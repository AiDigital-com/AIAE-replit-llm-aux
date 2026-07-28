package PACKAGE_REPLACE_ME.external.claude.model;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * A single message in a Claude API request.
 *
 * <p>Internal to the adapter — not exposed outside the external-services module.
 *
 * @param role    message role: {@code "user"} or {@code "assistant"}
 * @param content message text
 */
public record ClaudeMessage(
        @JsonProperty("role") String role,
        @JsonProperty("content") String content) {
}
