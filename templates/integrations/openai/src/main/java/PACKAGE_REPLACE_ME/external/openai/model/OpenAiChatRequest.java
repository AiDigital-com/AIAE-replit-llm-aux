package PACKAGE_REPLACE_ME.external.openai.model;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Request body for the OpenAI {@code /v1/chat/completions} endpoint.
 *
 * <p>Internal to the adapter — not exposed outside the external-services module.
 *
 * @param model      model identifier, e.g. {@code "gpt-4o"}
 * @param maxTokens  upper bound on generated tokens
 * @param messages   ordered conversation turns (system first, then user)
 */
public record OpenAiChatRequest(
        @JsonProperty("model") String model,
        @JsonProperty("max_tokens") int maxTokens,
        @JsonProperty("messages") List<OpenAiMessage> messages) {
}
