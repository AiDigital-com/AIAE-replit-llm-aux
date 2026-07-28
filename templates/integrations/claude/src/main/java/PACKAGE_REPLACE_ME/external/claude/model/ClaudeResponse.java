package PACKAGE_REPLACE_ME.external.claude.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Response body from the Anthropic Claude {@code /v1/messages} endpoint.
 *
 * <p>Internal to the adapter — not exposed outside the external-services module.
 *
 * @param id      unique message identifier
 * @param type    response type
 * @param content list of content blocks
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ClaudeResponse(
        @JsonProperty("id") String id,
        @JsonProperty("type") String type,
        @JsonProperty("content") List<ClaudeContentBlock> content) {
}
