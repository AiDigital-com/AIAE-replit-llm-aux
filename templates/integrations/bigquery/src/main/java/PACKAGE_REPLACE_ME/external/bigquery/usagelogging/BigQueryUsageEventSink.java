package PACKAGE_REPLACE_ME.external.bigquery.usagelogging;

import PACKAGE_REPLACE_ME.external.bigquery.BigQueryClient;
import PACKAGE_REPLACE_ME.external.bigquery.config.BigQueryProperties;
import PACKAGE_REPLACE_ME.usagelogging.models.UsageEvent;
import PACKAGE_REPLACE_ME.usagelogging.sink.UsageEventSink;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Exports usage events to BigQuery when {@link BigQueryClient} is active.
 */
@Component
@Qualifier("bigqueryUsageEventSink")
@ConditionalOnBean(BigQueryClient.class)
public class BigQueryUsageEventSink implements UsageEventSink {

    private static final String USAGE_TABLE = "usage_events";
    private static final String FIELD_EVENT_ID = "event_id";
    private static final String FIELD_EVENT_TIMESTAMP = "event_timestamp";
    private static final String FIELD_SERVICE = "service";
    private static final String FIELD_ENVIRONMENT = "environment";
    private static final String FIELD_EVENT_TYPE = "event_type";
    private static final String FIELD_ACTION = "action";
    private static final String FIELD_USER_ID = "user_id";
    private static final String FIELD_USER_EMAIL = "user_email";
    private static final String FIELD_STATUS = "status";
    private static final String FIELD_DURATION_MS = "duration_ms";
    private static final String FIELD_ATTRIBUTES = "attributes";
    private static final String FIELD_ERROR_MESSAGE = "error_message";
    private static final String FIELD_CLIENT_IP = "client_ip";
    private static final String FIELD_USER_AGENT = "user_agent";

    private final BigQueryClient bigQueryClient;
    private final BigQueryProperties properties;

    public BigQueryUsageEventSink(BigQueryClient bigQueryClient, BigQueryProperties properties) {
        this.bigQueryClient = bigQueryClient;
        this.properties = properties;
    }

    @Override
    public void record(UsageEvent event) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put(FIELD_EVENT_ID, event.eventId());
        row.put(FIELD_EVENT_TIMESTAMP, event.eventTimestamp());
        row.put(FIELD_SERVICE, event.service());
        row.put(FIELD_ENVIRONMENT, event.environment());
        row.put(FIELD_EVENT_TYPE, event.eventType());
        row.put(FIELD_ACTION, event.action());
        row.put(FIELD_USER_ID, event.userId());
        row.put(FIELD_USER_EMAIL, event.userEmail());
        row.put(FIELD_STATUS, event.status());
        row.put(FIELD_DURATION_MS, event.durationMs());
        row.put(FIELD_ATTRIBUTES, event.attributes());
        row.put(FIELD_ERROR_MESSAGE, event.errorMessage());
        row.put(FIELD_CLIENT_IP, event.clientIp());
        row.put(FIELD_USER_AGENT, event.userAgent());
        bigQueryClient.insertRow(USAGE_TABLE, row);
    }
}
