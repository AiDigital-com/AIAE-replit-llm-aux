package PACKAGE_REPLACE_ME.external.bigquery.impl;

import PACKAGE_REPLACE_ME.external.bigquery.config.BigQueryProperties;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThatCode;

class BigQueryStubClientTest {

    @Test
    void shouldAcceptInsertWithoutCredentialsTest() {
        BigQueryProperties props = new BigQueryProperties();
        props.setProjectId("demo");
        props.setDataset("analytics");
        BigQueryStubClient client = new BigQueryStubClient(props);

        assertThatCode(() -> client.insertRow("usage_events", Map.of("event_id", "e1")))
            .doesNotThrowAnyException();
    }
}
