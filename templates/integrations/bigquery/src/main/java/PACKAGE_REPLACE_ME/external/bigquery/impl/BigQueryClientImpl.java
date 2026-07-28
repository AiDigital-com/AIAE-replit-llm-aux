package PACKAGE_REPLACE_ME.external.bigquery.impl;

import PACKAGE_REPLACE_ME.external.bigquery.BigQueryClient;
import PACKAGE_REPLACE_ME.external.bigquery.BigQueryExternalException;
import PACKAGE_REPLACE_ME.external.bigquery.config.BigQueryProperties;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.bigquery.BigQuery;
import com.google.cloud.bigquery.BigQueryOptions;
import com.google.cloud.bigquery.InsertAllRequest;
import com.google.cloud.bigquery.InsertAllResponse;
import com.google.cloud.bigquery.TableId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;

/**
 * Production implementation of {@link BigQueryClient} backed by the
 * {@code com.google.cloud:google-cloud-bigquery} SDK.
 *
 * <p>A service-account JSON key is loaded once at construction from the raw
 * JSON string in {@link BigQueryProperties#getCredentialsJson()}. The credential
 * string is never logged.
 *
 * <p>Rows are inserted via the BigQuery Storage Write API's streaming-insert
 * path ({@link BigQuery#insertAll}). For high-volume ingestion consider
 * replacing this with the BigQuery Write API client.
 *
 * <p>Error mapping:
 * <ul>
 *   <li>Credential load failure → {@link BigQueryExternalException} at startup</li>
 *   <li>Row-level insertion errors → {@link BigQueryExternalException} with error detail</li>
 *   <li>SDK exceptions → {@link BigQueryExternalException} wrapping the cause</li>
 * </ul>
 */
public class BigQueryClientImpl implements BigQueryClient {

    private static final Logger LOG = LoggerFactory.getLogger(BigQueryClientImpl.class);

    private final BigQueryProperties properties;
    private final BigQuery bigQuery;

    /**
     * Package-private constructor for unit testing — accepts a pre-built BigQuery service.
     *
     * @param properties BigQuery configuration (project ID, dataset, credentials JSON)
     * @param bigQuery   pre-built BigQuery SDK service instance
     */
    BigQueryClientImpl(BigQueryProperties properties, com.google.cloud.bigquery.BigQuery bigQuery) {
        this.properties = properties;
        this.bigQuery = bigQuery;
    }

    /**
     * Constructs the client and authenticates using the configured service-account JSON.
     *
     * @param properties BigQuery configuration (project ID, dataset, credentials JSON)
     * @throws BigQueryExternalException when credentials cannot be loaded
     */
    public BigQueryClientImpl(BigQueryProperties properties) {
        this.properties = properties;
        LOG.info("Initialising BigQuery client: project={}, dataset={}",
                properties.getProjectId(), properties.getDataset());
        try {
            GoogleCredentials credentials = GoogleCredentials
                .fromStream(new ByteArrayInputStream(properties.getCredentialsJson().getBytes(StandardCharsets.UTF_8)))
                .createScoped("https://www.googleapis.com/auth/bigquery.insertdata");
            this.bigQuery = BigQueryOptions.newBuilder()
                .setProjectId(properties.getProjectId())
                .setCredentials(credentials)
                .build()
                .getService();
        } catch (IOException ex) {
            throw new BigQueryExternalException(
                "Failed to load BigQuery credentials — check BIGQUERY_CREDENTIALS_JSON", ex);
        }
    }

    /**
     * {@inheritDoc}
     *
     * <p>Inserts a single row into the configured dataset. Row keys must match
     * the target table's schema; unknown fields are rejected by BigQuery unless
     * the table has {@code ignoreUnknownValues} configured.
     *
     * @throws BigQueryExternalException on row-level errors or SDK failure
     */
    @Override
    public void insertRow(String table, Map<String, Object> row) {
        LOG.debug("Inserting row into BigQuery: project={}, dataset={}, table={}",
                properties.getProjectId(), properties.getDataset(), table);
        TableId tableId = TableId.of(properties.getDataset(), table);
        InsertAllRequest request = InsertAllRequest.newBuilder(tableId)
            .addRow(InsertAllRequest.RowToInsert.of(row))
            .build();
        try {
            InsertAllResponse response = bigQuery.insertAll(request);
            if (response.hasErrors()) {
                throw new BigQueryExternalException(
                    "BigQuery insertAll returned row-level errors for table="
                        + table + ": " + response.getInsertErrors());
            }
        } catch (BigQueryExternalException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new BigQueryExternalException(
                "BigQuery insertAll failed for table=" + table, ex);
        }
    }
}
