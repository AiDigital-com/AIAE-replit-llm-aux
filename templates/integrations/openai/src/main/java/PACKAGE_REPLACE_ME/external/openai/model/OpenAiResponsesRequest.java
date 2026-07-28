package PACKAGE_REPLACE_ME.external.openai.model;

import com.fasterxml.jackson.annotation.JsonProperty;


/**
 * Request body for the OpenAI Responses API ({@code POST /v1/responses}).
 *
 * @param model model identifier
 * @param input plain-text or structured input items
 * @param maxOutputTokens optional output token cap
 */
public record OpenAiResponsesRequest(
    @JsonProperty("model") String model,
    @JsonProperty("input") Object input,
    @JsonProperty("max_output_tokens") Integer maxOutputTokens
) {
}
