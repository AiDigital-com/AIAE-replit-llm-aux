package PACKAGE_REPLACE_ME.external.bigquery.impl;

import PACKAGE_REPLACE_ME.external.bigquery.BigQueryExternalException;
import PACKAGE_REPLACE_ME.external.bigquery.config.BigQueryProperties;
import com.google.cloud.bigquery.BigQuery;
import com.google.cloud.bigquery.InsertAllRequest;
import com.google.cloud.bigquery.InsertAllResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link BigQueryClientImpl}.
 *
 * <p>Uses the package-private testable constructor to inject a mock
 * {@link BigQuery} service, keeping tests free of real Google API calls.
 */
@ExtendWith(MockitoExtension.class)
class BigQueryClientImplTest {

    @Mock
    private BigQuery bigQuery;

    @Mock
    private InsertAllResponse insertAllResponse;

    private BigQueryProperties properties;
    private BigQueryClientImpl client;

    @BeforeEach
    void setUp() {
        properties = new BigQueryProperties();
        properties.setProjectId("test-project");
        properties.setDataset("test-dataset");
        properties.setCredentialsJson("{\"type\":\"service_account\"}");

        client = new BigQueryClientImpl(properties, bigQuery);
    }

    @Test
    void shouldCallInsertAllWithCorrectTableIdTest() {
        // Given:
        when(bigQuery.insertAll(any(InsertAllRequest.class))).thenReturn(insertAllResponse);
        when(insertAllResponse.hasErrors()).thenReturn(false);
        Map<String, Object> row = Map.of("field1", "value1");

        // When:
        client.insertRow("events", row);

        // Then:
        ArgumentCaptor<InsertAllRequest> captor = ArgumentCaptor.forClass(InsertAllRequest.class);
        verify(bigQuery).insertAll(captor.capture());
        assertThat(captor.getValue().getTable().getDataset()).isEqualTo("test-dataset");
        assertThat(captor.getValue().getTable().getTable()).isEqualTo("events");
    }

    @Test
    void shouldThrowBigQueryExternalExceptionOnRowLevelErrorsTest() {
        // Given:
        when(bigQuery.insertAll(any(InsertAllRequest.class))).thenReturn(insertAllResponse);
        when(insertAllResponse.hasErrors()).thenReturn(true);
        when(insertAllResponse.getInsertErrors()).thenReturn(Map.of());
        Map<String, Object> row = Map.of("field1", "value1");

        // When / Then:
        assertThatThrownBy(() -> client.insertRow("events", row))
                .isInstanceOf(BigQueryExternalException.class)
                .hasMessageContaining("row-level errors");
    }

    @Test
    void shouldThrowBigQueryExternalExceptionOnSdkExceptionTest() {
        // Given:
        when(bigQuery.insertAll(any(InsertAllRequest.class)))
                .thenThrow(new RuntimeException("network failure"));
        Map<String, Object> row = Map.of("field1", "value1");

        // When / Then:
        assertThatThrownBy(() -> client.insertRow("events", row))
                .isInstanceOf(BigQueryExternalException.class)
                .hasMessageContaining("BigQuery insertAll failed");
    }

    @Test
    void shouldIncludeTableNameInExceptionMessageTest() {
        // Given:
        when(bigQuery.insertAll(any(InsertAllRequest.class)))
                .thenThrow(new RuntimeException("timeout"));
        Map<String, Object> row = Map.of("col", "val");

        // When / Then:
        assertThatThrownBy(() -> client.insertRow("audit_log", row))
                .isInstanceOf(BigQueryExternalException.class)
                .hasMessageContaining("audit_log");
    }

    @Test
    void shouldSendRowDataInInsertAllRequestTest() {
        // Given:
        when(bigQuery.insertAll(any(InsertAllRequest.class))).thenReturn(insertAllResponse);
        when(insertAllResponse.hasErrors()).thenReturn(false);
        Map<String, Object> row = Map.of("user_id", "u-123", "action", "login");

        // When:
        client.insertRow("events", row);

        // Then:
        ArgumentCaptor<InsertAllRequest> captor = ArgumentCaptor.forClass(InsertAllRequest.class);
        verify(bigQuery).insertAll(captor.capture());
        InsertAllRequest captured = captor.getValue();
        assertThat(captured.getRows()).hasSize(1);
        assertThat(captured.getRows().get(0).getContent())
                .containsEntry("user_id", "u-123")
                .containsEntry("action", "login");
    }
}
