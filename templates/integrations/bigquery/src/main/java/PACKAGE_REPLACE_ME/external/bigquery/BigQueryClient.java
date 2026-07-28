package PACKAGE_REPLACE_ME.external.bigquery;

import java.util.Map;

/**
 * Narrow application-facing interface for BigQuery row insertion.
 *
 * <p>Credentials are sourced from properties only and are never logged.
 * Used as an opt-in analytics sink; the default baseline usage-logging
 * sink is the PostgreSQL {@code usage_events} table.
 *
 * @see BigQueryExternalException for error semantics
 */
public interface BigQueryClient {

    /**
     * Inserts a single row into the configured BigQuery dataset.
     *
     * @param table qualified table name within the configured dataset
     * @param row   map of column names to values (BigQuery-compatible types only)
     * @throws BigQueryExternalException on insertion failure or credential error
     */
    void insertRow(String table, Map<String, Object> row);
}
