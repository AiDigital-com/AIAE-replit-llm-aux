package PACKAGE_REPLACE_ME.external.common.http;

import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManager;
import org.springframework.web.client.RestClient;

import java.io.IOException;

/**
 * Holds pooled HTTP resources created for one logical external service.
 */
public final class ManagedPooledRestClient implements AutoCloseable {

    private final String name;
    private final RestClient restClient;
    private final CloseableHttpClient httpClient;
    private final PoolingHttpClientConnectionManager connectionManager;

    public ManagedPooledRestClient(
        String name,
        RestClient restClient,
        CloseableHttpClient httpClient,
        PoolingHttpClientConnectionManager connectionManager
    ) {
        this.name = name;
        this.restClient = restClient;
        this.httpClient = httpClient;
        this.connectionManager = connectionManager;
    }

    /**
     * Returns the logical external service name assigned to this client.
     *
     * @return client name used in diagnostics
     */
    public String name() {
        return name;
    }

    /**
     * Returns the Spring {@link RestClient} backed by the managed HTTP pool.
     *
     * @return pooled REST client
     */
    public RestClient restClient() {
        return restClient;
    }

    @Override
    public void close() {
        try {
            httpClient.close();
        } catch (IOException ignored) {
            // best-effort shutdown
        }
        connectionManager.close();
    }
}
