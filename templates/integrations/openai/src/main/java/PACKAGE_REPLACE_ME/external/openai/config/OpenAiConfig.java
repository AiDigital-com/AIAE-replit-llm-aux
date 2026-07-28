package PACKAGE_REPLACE_ME.external.openai.config;

import PACKAGE_REPLACE_ME.external.common.http.PooledRestClientFactory;
import PACKAGE_REPLACE_ME.external.openai.OpenAiClient;
import PACKAGE_REPLACE_ME.external.openai.impl.OpenAiClientImpl;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Registers {@link OpenAiClientImpl} when {@code app.external.openai.enabled=true}.
 */
@Configuration
@EnableConfigurationProperties(OpenAiProperties.class)
public class OpenAiConfig {

    /**
     * Creates the OpenAI adapter when the integration is explicitly enabled.
     *
     * @param properties OpenAI integration properties
     * @param factory pooled HTTP client factory
     * @return configured OpenAI client
     */
    @Bean
    @ConditionalOnProperty(prefix = "app.external.openai", name = "enabled", havingValue = "true")
    public OpenAiClient openAiClient(OpenAiProperties properties, PooledRestClientFactory factory) {
        if (properties.getApiKey() == null || properties.getApiKey().isBlank()) {
            throw new IllegalStateException(
                "app.external.openai.api-key must be set when OpenAI is enabled. "
                    + "Set OPENAI_API_KEY or disable via OPENAI_ENABLED=false.");
        }
        return new OpenAiClientImpl(properties, factory);
    }
}
