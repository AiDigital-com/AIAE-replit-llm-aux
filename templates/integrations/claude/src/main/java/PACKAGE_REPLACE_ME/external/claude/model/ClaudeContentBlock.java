package PACKAGE_REPLACE_ME.external.claude.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * A single content block in a Claude API response.
 *
 * <p>Internal to the adapter — not exposed outside the external-services module.
 *
 * @param type  block type, typically {@code "text"}
 * @param text  text content when {@code type} is {@code "text"}
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ClaudeContentBlock(
        @JsonProperty("type") String type,
        @JsonProperty("text") String text) {
}
