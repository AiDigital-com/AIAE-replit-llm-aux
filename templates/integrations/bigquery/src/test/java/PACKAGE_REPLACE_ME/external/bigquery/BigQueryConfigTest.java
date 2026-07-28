package PACKAGE_REPLACE_ME.external.bigquery;

import PACKAGE_REPLACE_ME.external.bigquery.config.BigQueryConfig;
import PACKAGE_REPLACE_ME.external.bigquery.config.BigQueryProperties;
import PACKAGE_REPLACE_ME.external.bigquery.impl.BigQueryClientImpl;
import PACKAGE_REPLACE_ME.external.bigquery.impl.BigQueryStubClient;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class BigQueryConfigTest {

    private final BigQueryConfig config = new BigQueryConfig();

    @Test
    void shouldProvideStubClientWhenStubEnabledTest() {
        BigQueryProperties props = new BigQueryProperties();
        props.setStubEnabled(true);
        props.setProjectId("demo-project");
        props.setDataset("analytics");

        assertThat(config.bigQueryStubClient(props)).isInstanceOf(BigQueryStubClient.class);
    }

    @Test
    void shouldFailFastWhenCredentialsMissingTest() {
        BigQueryProperties props = new BigQueryProperties();
        props.setEnabled(true);
        props.setCredentialsJson("");
        props.setProjectId("my-project");

        assertThatThrownBy(() -> config.bigQueryClient(props))
            .isInstanceOf(IllegalStateException.class)
            .hasMessageContaining("credentials-json");
    }

    @Test
    void shouldFailFastWhenProjectIdMissingTest() {
        BigQueryProperties props = new BigQueryProperties();
        props.setEnabled(true);
        props.setCredentialsJson("{\"type\":\"service_account\"}");
        props.setProjectId("");

        assertThatThrownBy(() -> config.bigQueryClient(props))
            .isInstanceOf(IllegalStateException.class)
            .hasMessageContaining("project-id");
    }

    @Test
    void shouldNotLeakCredentialJsonInFailFastMessageTest() {
        BigQueryProperties props = new BigQueryProperties();
        props.setEnabled(true);
        props.setCredentialsJson("super-secret-json");
        props.setProjectId("");

        assertThatThrownBy(() -> config.bigQueryClient(props))
            .isInstanceOf(IllegalStateException.class)
            .satisfies(ex -> assertThat(ex.getMessage()).doesNotContain("super-secret-json"));
    }

    @Test
    void shouldCreateProductionClientWhenConfiguredTest() {
        BigQueryProperties props = new BigQueryProperties();
        props.setEnabled(true);
        props.setCredentialsJson("{\"type\":\"service_account\"}");
        props.setProjectId("my-project");
        props.setDataset("analytics");

        assertThat(config.bigQueryClient(props)).isInstanceOf(BigQueryClientImpl.class);
    }
}
