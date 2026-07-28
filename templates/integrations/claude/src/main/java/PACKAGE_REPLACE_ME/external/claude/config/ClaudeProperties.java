package PACKAGE_REPLACE_ME.external.claude.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Runtime-tunable properties for the Claude API adapter.
 *
 * <p>All fields bind from the {@code app.external.claude.*} namespace.
 *
 * <p>Typical {@code application.yml} stubs:
 * <pre>
 * app:
 *   external:
 *     claude:
 *       enabled: ${CLAUDE_ENABLED:false}
 *       base-url: ${CLAUDE_BASE_URL:https://api.anthropic.com}
 *       api-key: ${CLAUDE_API_KEY:}
 *       api-version: ${CLAUDE_API_VERSION:2023-06-01}
 *       model: ${CLAUDE_MODEL:claude-3-5-sonnet-20241022}
 *       max-tokens: ${CLAUDE_MAX_TOKENS:1024}
 * </pre>
 */
@ConfigurationProperties(prefix = "app.external.claude")
@Validated
public class ClaudeProperties {

    private boolean enabled = false;
    private String baseUrl = "https://api.anthropic.com";
    private String apiKey = "";
    private String apiVersion = "2023-06-01";
    private String model = "claude-3-5-sonnet-20241022";
    private int maxTokens = 1024;

    /**
     * Returns whether the Claude integration is enabled.
     *
     * @return {@code true} if the integration is active
     */
    public boolean isEnabled() {
        return enabled;
    }

    /**
     * Sets whether the Claude integration is enabled.
     *
     * @param enabled {@code true} to enable
     */
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    /**
     * Returns the Claude API base URL.
     *
     * @return base URL
     */
    public String getBaseUrl() {
        return baseUrl;
    }

    /**
     * Sets the Claude API base URL.
     *
     * @param baseUrl base URL (must not end with a slash)
     */
    public void setBaseUrl(String baseUrl) {
        this.baseUrl = baseUrl;
    }

    /**
     * Returns the Anthropic API key.
     * Never log or expose this value.
     *
     * @return API key
     */
    public String getApiKey() {
        return apiKey;
    }

    /**
     * Sets the Anthropic API key.
     *
     * @param apiKey API key
     */
    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    /**
     * Returns the Anthropic API version header value.
     *
     * @return API version string, e.g. {@code "2023-06-01"}
     */
    public String getApiVersion() {
        return apiVersion;
    }

    /**
     * Sets the Anthropic API version header value.
     *
     * @param apiVersion API version string
     */
    public void setApiVersion(String apiVersion) {
        this.apiVersion = apiVersion;
    }

    /**
     * Returns the Claude model identifier.
     *
     * @return model identifier
     */
    public String getModel() {
        return model;
    }

    /**
     * Sets the Claude model identifier.
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
