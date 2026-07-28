package PACKAGE_REPLACE_ME.external.openai.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Response body from the OpenAI {@code /v1/chat/completions} endpoint.
 *
 * <p>Internal to the adapter — not exposed outside the external-services module.
 *
 * @param id      unique completion identifier
 * @param choices list of generated completion choices
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record OpenAiChatResponse(
        @JsonProperty("id") String id,
        @JsonProperty("choices") List<Choice> choices) {

    /**
     * A single completion choice returned by the OpenAI API.
     *
     * @param message      the generated message
     * @param finishReason why the model stopped generating
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Choice(
            @JsonProperty("message") OpenAiMessage message,
            @JsonProperty("finish_reason") String finishReason) {
    }
}
