package PACKAGE_REPLACE_ME.external.claude.model;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Request body for the Anthropic Claude {@code /v1/messages} endpoint.
 *
 * <p>Internal to the adapter — not exposed outside the external-services module.
 *
 * @param model      model identifier, e.g. {@code "claude-3-5-sonnet-20241022"}
 * @param maxTokens  upper bound on the number of tokens to generate
 * @param system     system prompt providing context for the model
 * @param messages   conversation turns
 */
public record ClaudeRequest(
        @JsonProperty("model") String model,
        @JsonProperty("max_tokens") int maxTokens,
        @JsonProperty("system") String system,
        @JsonProperty("messages") List<ClaudeMessage> messages) {
}
