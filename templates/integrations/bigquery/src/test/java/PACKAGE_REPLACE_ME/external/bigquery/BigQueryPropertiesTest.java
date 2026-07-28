package PACKAGE_REPLACE_ME.external.bigquery;

import PACKAGE_REPLACE_ME.external.bigquery.config.BigQueryProperties;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for {@link BigQueryProperties} default values.
 */
class BigQueryPropertiesTest {

    @Test
    void shouldApplyDefaultValuesTest() {
        // Given / When:
        BigQueryProperties props = new BigQueryProperties();

        // Then:
        assertThat(props.isEnabled()).isFalse();
        assertThat(props.isStubEnabled()).isFalse();
        assertThat(props.getCredentialsJson()).isEmpty();
        assertThat(props.getProjectId()).isEmpty();
        assertThat(props.getDataset()).isEmpty();
        assertThat(props.getLocation()).isEqualTo("US");
    }

    @Test
    void shouldApplyCustomValuesTest() {
        // Given:
        BigQueryProperties props = new BigQueryProperties();

        // When:
        props.setEnabled(true);
        props.setStubEnabled(false);
        props.setCredentialsJson("{\"type\":\"service_account\"}");
        props.setProjectId("my-gcp-project");
        props.setDataset("analytics");
        props.setLocation("EU");

        // Then:
        assertThat(props.isEnabled()).isTrue();
        assertThat(props.getCredentialsJson()).isEqualTo("{\"type\":\"service_account\"}");
        assertThat(props.getProjectId()).isEqualTo("my-gcp-project");
        assertThat(props.getDataset()).isEqualTo("analytics");
        assertThat(props.getLocation()).isEqualTo("EU");
    }
}
