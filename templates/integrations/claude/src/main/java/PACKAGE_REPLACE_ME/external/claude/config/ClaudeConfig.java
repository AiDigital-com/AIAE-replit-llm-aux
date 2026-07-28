package PACKAGE_REPLACE_ME.external.claude.config;

import PACKAGE_REPLACE_ME.external.claude.ClaudeClient;
import PACKAGE_REPLACE_ME.external.claude.impl.ClaudeClientImpl;
import PACKAGE_REPLACE_ME.external.common.http.PooledRestClientFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Selects the active {@link ClaudeClient} implementation based on properties.
 *
 * <p>Selection rules:
 * <ul>
 *   <li>{@code app.external.claude.enabled=true} → {@link ClaudeClientImpl}
 *       with fail-fast validation that {@code api-key} is non-blank</li>
 *   <li>Not enabled → {@code null} bean (Claude is completely inactive)</li>
 * </ul>
 *
 * <p>The API key is never logged or exposed.
 */
@Configuration
@EnableConfigurationProperties(ClaudeProperties.class)
public class ClaudeConfig {

    /**
     * Provides the active {@link ClaudeClient} based on the configured properties.
     *
     * @param properties Claude configuration properties
     * @param factory    shared HTTP client factory
     * @return production client, or {@code null} when Claude is disabled
     */
    @Bean
    @ConditionalOnProperty(prefix = "app.external.claude", name = "enabled", havingValue = "true")
    public ClaudeClient claudeClient(ClaudeProperties properties, PooledRestClientFactory factory) {
        if (properties.getApiKey() == null || properties.getApiKey().isBlank()) {
            throw new IllegalStateException(
                "app.external.claude.api-key must be set when Claude is enabled. "
                    + "Set CLAUDE_API_KEY or disable via CLAUDE_ENABLED=false.");
        }
        return new ClaudeClientImpl(properties, factory);
    }
}
