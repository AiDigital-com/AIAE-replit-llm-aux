package PACKAGE_REPLACE_ME.external.bigquery.config;

import PACKAGE_REPLACE_ME.external.bigquery.BigQueryClient;
import PACKAGE_REPLACE_ME.external.bigquery.impl.BigQueryClientImpl;
import PACKAGE_REPLACE_ME.external.bigquery.impl.BigQueryStubClient;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Selects the active {@link BigQueryClient} implementation from properties.
 *
 * <p>{@code stub-enabled=true} activates {@link BigQueryStubClient} for local
 * development without Google credentials. Production mode requires
 * {@code enabled=true}, credentials, and project id.
 */
@Configuration
@EnableConfigurationProperties(BigQueryProperties.class)
public class BigQueryConfig {

    /**
     * Stub client for local development (no credentials).
     *
     * @param properties BigQuery configuration properties
     * @return in-memory stub client
     */
    @Bean
    @ConditionalOnProperty(prefix = "app.external.bigquery", name = "stub-enabled", havingValue = "true")
    public BigQueryClient bigQueryStubClient(BigQueryProperties properties) {
        return new BigQueryStubClient(properties);
    }

    /**
     * Production client backed by the Google Cloud SDK.
     *
     * @param properties BigQuery configuration properties
     * @return production client
     */
    @Bean
    @ConditionalOnExpression(
        "${app.external.bigquery.enabled:false} && !${app.external.bigquery.stub-enabled:false}")
    public BigQueryClient bigQueryClient(BigQueryProperties properties) {
        if (properties.getCredentialsJson() == null
                || properties.getCredentialsJson().isBlank()) {
            throw new IllegalStateException(
                    "app.external.bigquery.credentials-json must be set when BigQuery is enabled. "
                            + "Set BIGQUERY_CREDENTIALS_JSON to the service-account JSON string, "
                            + "or enable app.external.bigquery.stub-enabled for local development.");
        }
        if (properties.getProjectId() == null || properties.getProjectId().isBlank()) {
            throw new IllegalStateException(
                    "app.external.bigquery.project-id must be set when BigQuery is enabled. "
                            + "Set BIGQUERY_PROJECT_ID.");
        }
        return new BigQueryClientImpl(properties);
    }
}
