package PACKAGE_REPLACE_ME.external.common.http.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * Activates {@link PooledHttpClientProperties} binding.
 *
 * <p>{@code PooledRestClientFactory} is declared as {@code @Component}
 * and is auto-registered by Spring's component scan when this module is
 * on the classpath.
 */
@Configuration
@EnableConfigurationProperties(PooledHttpClientProperties.class)
public class HttpClientFoundationConfig {
}
