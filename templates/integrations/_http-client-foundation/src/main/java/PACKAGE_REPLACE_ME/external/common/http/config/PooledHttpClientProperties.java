package PACKAGE_REPLACE_ME.external.common.http.config;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

/**
 * Runtime-tunable properties for the shared pooled HTTP client.
 *
 * <p>All fields bind from the {@code app.external.http.*} namespace.
 * Validation is enforced at context startup via {@code @Validated}.
 *
 * <p>Typical {@code application.yml} stubs:
 * <pre>
 * app:
 *   external:
 *     http:
 *       connect-timeout: 5s
 *       response-timeout: 30s
 *       connection-request-timeout: 5s
 *       max-total-connections: 50
 *       max-connections-per-route: 10
 *       keep-alive-duration: 60s
 *       idle-eviction-duration: 30s
 * </pre>
 */
@ConfigurationProperties(prefix = "app.external.http")
@Validated
public class PooledHttpClientProperties {

    /** Maximum time to establish a TCP connection. */
    @NotNull
    private Duration connectTimeout = Duration.ofSeconds(5);

    /** Maximum time to wait for the first response byte after sending the request. */
    @NotNull
    private Duration responseTimeout = Duration.ofSeconds(30);

    /** Maximum time to wait for a connection lease from the pool. */
    @NotNull
    private Duration connectionRequestTimeout = Duration.ofSeconds(5);

    /** Maximum number of connections across all routes. */
    @Positive
    private int maxTotalConnections = 50;

    /** Maximum number of connections per individual route (host). */
    @Positive
    private int maxConnectionsPerRoute = 10;

    /** How long to keep a connection alive in the pool when idle. */
    @NotNull
    private Duration keepAliveDuration = Duration.ofSeconds(60);

    /** How long before idle connections are evicted from the pool. */
    @NotNull
    private Duration idleEvictionDuration = Duration.ofSeconds(30);

    /**
     * Returns the maximum time to establish a TCP connection.
     *
     * @return connect timeout
     */
    public Duration getConnectTimeout() {
        return connectTimeout;
    }

    /**
     * Sets the maximum time to establish a TCP connection.
     *
     * @param connectTimeout connect timeout
     */
    public void setConnectTimeout(Duration connectTimeout) {
        this.connectTimeout = connectTimeout;
    }

    /**
     * Returns the maximum time to wait for the first response byte.
     *
     * @return response timeout
     */
    public Duration getResponseTimeout() {
        return responseTimeout;
    }

    /**
     * Sets the maximum time to wait for the first response byte.
     *
     * @param responseTimeout response timeout
     */
    public void setResponseTimeout(Duration responseTimeout) {
        this.responseTimeout = responseTimeout;
    }

    /**
     * Returns the maximum time to wait for a pool connection lease.
     *
     * @return connection-request timeout
     */
    public Duration getConnectionRequestTimeout() {
        return connectionRequestTimeout;
    }

    /**
     * Sets the maximum time to wait for a pool connection lease.
     *
     * @param connectionRequestTimeout connection-request timeout
     */
    public void setConnectionRequestTimeout(Duration connectionRequestTimeout) {
        this.connectionRequestTimeout = connectionRequestTimeout;
    }

    /**
     * Returns the maximum number of connections across all routes.
     *
     * @return max total connections
     */
    public int getMaxTotalConnections() {
        return maxTotalConnections;
    }

    /**
     * Sets the maximum number of connections across all routes.
     *
     * @param maxTotalConnections max total connections
     */
    public void setMaxTotalConnections(int maxTotalConnections) {
        this.maxTotalConnections = maxTotalConnections;
    }

    /**
     * Returns the maximum number of connections per route.
     *
     * @return max connections per route
     */
    public int getMaxConnectionsPerRoute() {
        return maxConnectionsPerRoute;
    }

    /**
     * Sets the maximum number of connections per route.
     *
     * @param maxConnectionsPerRoute max connections per route
     */
    public void setMaxConnectionsPerRoute(int maxConnectionsPerRoute) {
        this.maxConnectionsPerRoute = maxConnectionsPerRoute;
    }

    /**
     * Returns how long idle connections are kept alive in the pool.
     *
     * @return keep-alive duration
     */
    public Duration getKeepAliveDuration() {
        return keepAliveDuration;
    }

    /**
     * Sets how long idle connections are kept alive in the pool.
     *
     * @param keepAliveDuration keep-alive duration
     */
    public void setKeepAliveDuration(Duration keepAliveDuration) {
        this.keepAliveDuration = keepAliveDuration;
    }

    /**
     * Returns how long before idle connections are evicted from the pool.
     *
     * @return idle eviction duration
     */
    public Duration getIdleEvictionDuration() {
        return idleEvictionDuration;
    }

    /**
     * Sets how long before idle connections are evicted from the pool.
     *
     * @param idleEvictionDuration idle eviction duration
     */
    public void setIdleEvictionDuration(Duration idleEvictionDuration) {
        this.idleEvictionDuration = idleEvictionDuration;
    }
}
