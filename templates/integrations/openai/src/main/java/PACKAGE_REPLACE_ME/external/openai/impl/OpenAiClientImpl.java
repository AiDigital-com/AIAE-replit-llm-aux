package PACKAGE_REPLACE_ME.external.openai.impl;

import PACKAGE_REPLACE_ME.external.common.http.PooledRestClientFactory;
import PACKAGE_REPLACE_ME.external.openai.OpenAiClient;
import PACKAGE_REPLACE_ME.external.openai.OpenAiExternalException;
import PACKAGE_REPLACE_ME.external.openai.config.OpenAiProperties;
import PACKAGE_REPLACE_ME.external.openai.model.OpenAiChatRequest;
import PACKAGE_REPLACE_ME.external.openai.model.OpenAiChatResponse;
import PACKAGE_REPLACE_ME.external.openai.model.OpenAiMessage;
import PACKAGE_REPLACE_ME.external.openai.model.OpenAiResponsesRequest;
import PACKAGE_REPLACE_ME.external.openai.model.OpenAiResponsesResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.ArrayList;
import java.util.List;

/**
 * Production {@link OpenAiClient} using the Responses API by default and Chat
 * Completions as an explicit legacy mode.
 */
public class OpenAiClientImpl implements OpenAiClient {

    private static final Logger LOG = LoggerFactory.getLogger(OpenAiClientImpl.class);

    private final OpenAiProperties properties;
    private final RestClient restClient;

    public OpenAiClientImpl(OpenAiProperties properties, PooledRestClientFactory factory) {
        this.properties = properties;
        this.restClient = factory.createClient("openai", properties.getBaseUrl());
    }

    @Override
    public String complete(String systemPrompt, String userMessage) {
        if (properties.isUseResponsesApi()) {
            return completeViaResponses(systemPrompt, userMessage);
        }
        return completeViaChatCompletions(systemPrompt, userMessage);
    }

    /**
     * Calls the OpenAI Responses API and extracts the first textual output.
     *
     * @param systemPrompt optional system prompt
     * @param userMessage user prompt to send
     * @return generated text
     */
    private String completeViaResponses(String systemPrompt, String userMessage) {
        Object input = userMessage;
        if (systemPrompt != null && !systemPrompt.isBlank()) {
            input = List.of(
                new OpenAiMessage("system", systemPrompt),
                new OpenAiMessage("user", userMessage));
        }
        OpenAiResponsesRequest request = new OpenAiResponsesRequest(
            properties.getModel(),
            input,
            properties.getMaxTokens());

        LOG.debug("Sending OpenAI Responses request: model={}", properties.getModel());

        try {
            OpenAiResponsesResponse response = restClient.post()
                .uri(properties.getResponsesPath())
                .header("Authorization", "Bearer " + properties.getApiKey())
                .contentType(MediaType.APPLICATION_JSON)
                .body(request)
                .retrieve()
                .onStatus(HttpStatusCode::isError, (req, res) -> {
                    String body = new String(res.getBody().readAllBytes());
                    throw new OpenAiExternalException(
                        "OpenAI API returned HTTP " + res.getStatusCode().value(),
                        res.getStatusCode().value(),
                        body);
                })
                .body(OpenAiResponsesResponse.class);

            return extractResponsesText(response);
        } catch (OpenAiExternalException ex) {
            throw ex;
        } catch (RestClientException ex) {
            throw new OpenAiExternalException("OpenAI API call failed: " + ex.getMessage(), ex);
        } catch (Exception ex) {
            throw new OpenAiExternalException("Unexpected error calling OpenAI API", ex);
        }
    }

    /**
     * Calls the legacy Chat Completions API and extracts the first message body.
     *
     * @param systemPrompt optional system prompt
     * @param userMessage user prompt to send
     * @return generated text
     */
    private String completeViaChatCompletions(String systemPrompt, String userMessage) {
        List<OpenAiMessage> messages = new ArrayList<>();
        if (systemPrompt != null && !systemPrompt.isBlank()) {
            messages.add(new OpenAiMessage("system", systemPrompt));
        }
        messages.add(new OpenAiMessage("user", userMessage));

        OpenAiChatRequest request = new OpenAiChatRequest(
            properties.getModel(),
            properties.getMaxTokens(),
            messages);

        LOG.debug("Sending OpenAI Chat Completions request: model={}", properties.getModel());

        try {
            OpenAiChatResponse response = restClient.post()
                .uri(properties.getChatCompletionsPath())
                .header("Authorization", "Bearer " + properties.getApiKey())
                .contentType(MediaType.APPLICATION_JSON)
                .body(request)
                .retrieve()
                .onStatus(HttpStatusCode::isError, (req, res) -> {
                    String body = new String(res.getBody().readAllBytes());
                    throw new OpenAiExternalException(
                        "OpenAI API returned HTTP " + res.getStatusCode().value(),
                        res.getStatusCode().value(),
                        body);
                })
                .body(OpenAiChatResponse.class);

            return extractChatText(response);
        } catch (OpenAiExternalException ex) {
            throw ex;
        } catch (RestClientException ex) {
            throw new OpenAiExternalException("OpenAI API call failed: " + ex.getMessage(), ex);
        } catch (Exception ex) {
            throw new OpenAiExternalException("Unexpected error calling OpenAI API", ex);
        }
    }

    /**
     * Extracts the first non-blank text part from a Responses API payload.
     *
     * @param response decoded OpenAI Responses API response
     * @return generated text
     */
    String extractResponsesText(OpenAiResponsesResponse response) {
        if (response == null || response.output() == null || response.output().isEmpty()) {
            throw new OpenAiExternalException("OpenAI Responses API returned empty output", -1, "");
        }
        for (OpenAiResponsesResponse.OutputItem item : response.output()) {
            if (item.content() == null) {
                continue;
            }
            for (OpenAiResponsesResponse.ContentPart part : item.content()) {
                if (part.text() != null && !part.text().isBlank()) {
                    return part.text();
                }
            }
        }
        throw new OpenAiExternalException("OpenAI Responses API returned no text content", -1, "");
    }

    /**
     * Extracts the first chat completion message from a Chat Completions payload.
     *
     * @param response decoded OpenAI Chat Completions response
     * @return generated text
     */
    String extractChatText(OpenAiChatResponse response) {
        if (response == null
            || response.choices() == null
            || response.choices().isEmpty()) {
            throw new OpenAiExternalException("OpenAI API returned empty choices", -1, "");
        }
        OpenAiChatResponse.Choice first = response.choices().get(0);
        if (first.message() == null || first.message().content() == null) {
            throw new OpenAiExternalException(
                "OpenAI API returned a choice with null content", -1, "");
        }
        return first.message().content();
    }
}
