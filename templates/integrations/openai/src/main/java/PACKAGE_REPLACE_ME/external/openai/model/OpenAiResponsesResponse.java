package PACKAGE_REPLACE_ME.external.openai.model;

import java.util.List;

/**
 * Minimal typed mapping for the OpenAI Responses API response body.
 *
 * @param output generated output items
 */
public record OpenAiResponsesResponse(List<OutputItem> output) {

    public record OutputItem(String type, List<ContentPart> content) { }

    public record ContentPart(String type, String text) { }
}
