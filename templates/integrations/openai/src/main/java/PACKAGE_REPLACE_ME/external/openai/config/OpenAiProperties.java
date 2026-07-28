package PACKAGE_REPLACE_ME.external.openai.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Runtime-tunable properties for the OpenAI adapter (Responses API default).
 *
 * <p>All fields bind from the {@code app.external.openai.*} namespace.
 *
 * <p>Typical {@code application.yml} stubs:
 * <pre>
 * app:
 *   external:
 *     openai:
 *       enabled: ${OPENAI_ENABLED:false}
 *       base-url: ${OPENAI_BASE_URL:https://api.openai.com}
 *       api-key: ${OPENAI_API_KEY:}
 *       model: ${OPENAI_MODEL:gpt-4o}
 *       max-tokens: ${OPENAI_MAX_TOKENS:1024}
 * </pre>
 */
@ConfigurationProperties(prefix = "app.external.openai")
@Validated
public class OpenAiProperties {

    private boolean enabled = false;
    private String baseUrl = "https://api.openai.com";
    private String apiKey = "";
    /** {@code responses} (default) or {@code chat-completions} (legacy). */
    private String apiMode = "responses";
    private String responsesPath = "/v1/responses";
    private String chatCompletionsPath = "/v1/chat/completions";
    private String model = "gpt-4o";
    private int maxTokens = 1024;

    /**
     * Returns whether the OpenAI integration is enabled.
     *
     * @return {@code true} if the integration is active
     */
    public boolean isEnabled() {
        return enabled;
    }

    /**
     * Sets whether the OpenAI integration is enabled.
     *
     * @param enabled {@code true} to enable
     */
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    /**
     * Returns the OpenAI API base URL.
     *
     * @return base URL
     */
    public String getBaseUrl() {
        return baseUrl;
    }

    /**
     * Sets the OpenAI API base URL.
     *
     * @param baseUrl base URL (must not end with a slash)
     */
    public void setBaseUrl(String baseUrl) {
        this.baseUrl = baseUrl;
    }

    /**
     * Returns the OpenAI API key.
     * Never log or expose this value.
     *
     * @return API key
     */
    public String getApiKey() {
        return apiKey;
    }

    /**
     * Sets the OpenAI API key.
     *
     * @param apiKey API key
     */
    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    /**
     * Returns whether the Responses API is selected (default).
     *
     * @return {@code true} for Responses API, {@code false} for legacy Chat Completions
     */
    public boolean isUseResponsesApi() {
        return apiMode == null || apiMode.isBlank() || "responses".equalsIgnoreCase(apiMode);
    }

    public String getApiMode() {
        return apiMode;
    }

    public void setApiMode(String apiMode) {
        this.apiMode = apiMode;
    }

    public String getResponsesPath() {
        return responsesPath;
    }

    public void setResponsesPath(String responsesPath) {
        this.responsesPath = responsesPath;
    }

    public String getChatCompletionsPath() {
        return chatCompletionsPath;
    }

    public void setChatCompletionsPath(String chatCompletionsPath) {
        this.chatCompletionsPath = chatCompletionsPath;
    }

    /**
     * Returns the OpenAI model identifier.
     *
     * @return model identifier
     */
    public String getModel() {
        return model;
    }

    /**
     * Sets the OpenAI model identifier.
     *
     * @param model model identifier
     */
    public void setModel(String model) {
        this.model = model;
    }

    /**
     * Returns the maximum number of tokens to generate per request.
     *
     * @return max tokens
     */
    public int getMaxTokens() {
        return maxTokens;
    }

    /**
     * Sets the maximum number of tokens to generate per request.
     *
     * @param maxTokens max tokens
     */
    public void setMaxTokens(int maxTokens) {
        this.maxTokens = maxTokens;
    }
}
