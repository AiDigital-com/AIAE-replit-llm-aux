package PACKAGE_REPLACE_ME.external.bigquery.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Runtime-tunable properties for the BigQuery adapter.
 *
 * <p>All fields bind from the {@code app.external.bigquery.*} namespace.
 *
 * <p>Typical {@code application.yml} stubs:
 * <pre>
 * app:
 *   external:
 *     bigquery:
 *       enabled: ${BIGQUERY_ENABLED:false}
 *       credentials-json: ${BIGQUERY_CREDENTIALS_JSON:}
 *       project-id: ${BIGQUERY_PROJECT_ID:}
 *       dataset: ${BIGQUERY_DATASET:}
 *       location: ${BIGQUERY_LOCATION:US}
 * </pre>
 *
 * <p>Security: {@code credentialsJson} must contain the raw service-account JSON
 * string. Store it in a secret manager / environment variable; never commit
 * credentials JSON to source control.
 *
 * <p>Usage note: the default analytics sink is the PostgreSQL {@code usage_events}
 * table. BigQuery is an opt-in export sink only.
 */
@ConfigurationProperties(prefix = "app.external.bigquery")
@Validated
public class BigQueryProperties {

    private boolean enabled = false;
    private boolean stubEnabled = false;
    private String credentialsJson = "";
    private String projectId = "";
    private String dataset = "";
    private String location = "US";

    /**
     * Returns whether the BigQuery integration is enabled.
     *
     * @return {@code true} if BigQuery is active
     */
    public boolean isEnabled() {
        return enabled;
    }

    /**
     * Sets whether the BigQuery integration is enabled.
     *
     * @param enabled {@code true} to enable
     */
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    /**
     * Returns whether the in-memory stub client is active (local dev without credentials).
     *
     * @return {@code true} when stub mode is enabled
     */
    public boolean isStubEnabled() {
        return stubEnabled;
    }

    /**
     * Sets whether the in-memory stub client is active.
     *
     * @param stubEnabled {@code true} to use the in-memory stub client
     */
    public void setStubEnabled(boolean stubEnabled) {
        this.stubEnabled = stubEnabled;
    }

    /**
     * Returns the raw service-account credentials JSON.
     *
     * @return credentials JSON string; empty when not configured
     */
    public String getCredentialsJson() {
        return credentialsJson;
    }

    /**
     * Sets the raw service-account credentials JSON.
     *
     * @param credentialsJson service-account JSON string
     */
    public void setCredentialsJson(String credentialsJson) {
        this.credentialsJson = credentialsJson;
    }

    /**
     * Returns the Google Cloud project ID.
     *
     * @return project ID
     */
    public String getProjectId() {
        return projectId;
    }

    /**
     * Sets the Google Cloud project ID.
     *
     * @param projectId project ID
     */
    public void setProjectId(String projectId) {
        this.projectId = projectId;
    }

    /**
     * Returns the BigQuery dataset name.
     *
     * @return dataset name
     */
    public String getDataset() {
        return dataset;
    }

    /**
     * Sets the BigQuery dataset name.
     *
     * @param dataset dataset name
     */
    public void setDataset(String dataset) {
        this.dataset = dataset;
    }

    /**
     * Returns the BigQuery dataset location (e.g. {@code "US"}, {@code "EU"}).
     *
     * @return location string
     */
    public String getLocation() {
        return location;
    }

    /**
     * Sets the BigQuery dataset location.
     *
     * @param location location string
     */
    public void setLocation(String location) {
        this.location = location;
    }
}
