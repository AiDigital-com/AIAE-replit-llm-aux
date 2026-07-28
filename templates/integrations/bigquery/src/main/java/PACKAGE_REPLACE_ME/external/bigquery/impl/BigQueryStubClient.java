package PACKAGE_REPLACE_ME.external.bigquery.impl;

import PACKAGE_REPLACE_ME.external.bigquery.BigQueryClient;
import PACKAGE_REPLACE_ME.external.bigquery.config.BigQueryProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;

/**
 * In-memory BigQuery client for local development without Google credentials.
 */
public class BigQueryStubClient implements BigQueryClient {

    private static final Logger LOG = LoggerFactory.getLogger(BigQueryStubClient.class);

    private final BigQueryProperties properties;

    public BigQueryStubClient(BigQueryProperties properties) {
        this.properties = properties;
    }

    @Override
    public void insertRow(String table, Map<String, Object> row) {
        LOG.debug(
            "BigQuery stub insert: project={}, dataset={}, table={}, eventId={}",
            properties.getProjectId(),
            properties.getDataset(),
            table,
            row.get("event_id"));
    }
}
