package PACKAGE_REPLACE_ME.external.claude.impl;

import PACKAGE_REPLACE_ME.external.claude.ClaudeClient;
import PACKAGE_REPLACE_ME.external.claude.ClaudeExternalException;
import PACKAGE_REPLACE_ME.external.claude.config.ClaudeProperties;
import PACKAGE_REPLACE_ME.external.claude.model.ClaudeContentBlock;
import PACKAGE_REPLACE_ME.external.claude.model.ClaudeMessage;
import PACKAGE_REPLACE_ME.external.claude.model.ClaudeRequest;
import PACKAGE_REPLACE_ME.external.claude.model.ClaudeResponse;
import PACKAGE_REPLACE_ME.external.common.http.PooledRestClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.List;

/**
 * Production implementation of {@link ClaudeClient} using the Anthropic
 * {@code /v1/messages} REST endpoint.
 *
 * <p>Security: the API key is never logged. Prompt and response bodies are
 * never logged at any log level by default.
 *
 * <p>Error mapping:
 * <ul>
 *   <li>Non-2xx → {@link ClaudeExternalException} with status code and body</li>
 *   <li>Timeout or I/O → {@link ClaudeExternalException} wrapping the cause</li>
 *   <li>Malformed JSON / empty content → {@link ClaudeExternalException}</li>
 * </ul>
 */
public class ClaudeClientImpl implements ClaudeClient {

    private static final Logger LOG = LoggerFactory.getLogger(ClaudeClientImpl.class);

    private static final String MESSAGES_PATH = "/v1/messages";

    private final ClaudeProperties properties;
    private final RestClient restClient;

    /**
     * Constructs the production client using shared HTTP infrastructure.
     *
     * @param properties Claude configuration properties
     * @param factory    shared pooled HTTP client factory
     */
    public ClaudeClientImpl(ClaudeProperties properties, PooledRestClientFactory factory) {
        this.properties = properties;
        this.restClient = factory.createClient("claude", properties.getBaseUrl());
    }

    /**
     * Sends a completion request to the Claude API.
     *
     * @param systemPrompt instruction context for the model (may be blank)
     * @param userMessage  user-facing prompt text
     * @return the model's text response
     * @throws ClaudeExternalException on HTTP error, timeout, or malformed response
     */
    @Override
    public String complete(String systemPrompt, String userMessage) {
        ClaudeRequest request = new ClaudeRequest(
                properties.getModel(),
                properties.getMaxTokens(),
                systemPrompt,
                List.of(new ClaudeMessage("user", userMessage)));

        LOG.debug("Sending Claude request: model={}, maxTokens={}",
                properties.getModel(), properties.getMaxTokens());

        try {
            ClaudeResponse response = restClient.post()
                    .uri(MESSAGES_PATH)
                    .header("anthropic-version", properties.getApiVersion())
                    .header("x-api-key", properties.getApiKey())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(request)
                    .retrieve()
                    .onStatus(HttpStatusCode::isError, (req, res) -> {
                        String body = new String(res.getBody().readAllBytes());
                        throw new ClaudeExternalException(
                                "Claude API returned HTTP " + res.getStatusCode().value(),
                                res.getStatusCode().value(),
                                body);
                    })
                    .body(ClaudeResponse.class);

            return extractText(response);
        } catch (ClaudeExternalException ex) {
            throw ex;
        } catch (RestClientException ex) {
            throw new ClaudeExternalException("Claude API call failed: " + ex.getMessage(), ex);
        } catch (Exception ex) {
            throw new ClaudeExternalException("Unexpected error calling Claude API", ex);
        }
    }

    /**
     * Extracts the first text content block from a Claude response.
     *
     * @param response deserialized API response
     * @return text content of the first text block
     * @throws ClaudeExternalException when the response is null, empty, or contains no text block
     */
    String extractText(ClaudeResponse response) {
        if (response == null || response.content() == null || response.content().isEmpty()) {
            throw new ClaudeExternalException(
                    "Claude API returned empty content", -1, "");
        }
        return response.content().stream()
                .filter(b -> "text".equals(b.type()))
                .map(ClaudeContentBlock::text)
                .findFirst()
                .orElseThrow(() -> new ClaudeExternalException(
                        "Claude API response contained no text content block", -1, ""));
    }
}
