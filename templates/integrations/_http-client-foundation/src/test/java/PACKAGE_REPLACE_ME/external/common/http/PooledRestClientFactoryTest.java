package PACKAGE_REPLACE_ME.external.common.http;

import PACKAGE_REPLACE_ME.external.common.http.config.PooledHttpClientProperties;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManager;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClient;
import org.zalando.logbook.Logbook;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests that {@link PooledRestClientFactory} applies configured pool limits and
 * produces a functional {@link RestClient}.
 */
class PooledRestClientFactoryTest {

    private PooledRestClientFactory factory(PooledHttpClientProperties properties) {
        return new PooledRestClientFactory(
            Logbook.builder().build(), new SimpleMeterRegistry(), properties);
    }

    private PooledHttpClientProperties defaultProperties() {
        PooledHttpClientProperties props = new PooledHttpClientProperties();
        props.setMaxTotalConnections(50);
        props.setMaxConnectionsPerRoute(10);
        props.setConnectTimeout(Duration.ofSeconds(5));
        props.setResponseTimeout(Duration.ofSeconds(30));
        props.setConnectionRequestTimeout(Duration.ofSeconds(5));
        props.setKeepAliveDuration(Duration.ofSeconds(60));
        props.setIdleEvictionDuration(Duration.ofSeconds(30));
        return props;
    }

    @Test
    void shouldReturnNonNullRestClientTest() {
        // Given:
        PooledRestClientFactory factory = factory(defaultProperties());

        // When:
        RestClient client = factory.createClient("test", "https://example.com");

        // Then:
        assertThat(client).isNotNull();
    }

    @Test
    void shouldApplyMaxTotalConnectionsTest() {
        // Given:
        PooledHttpClientProperties props = defaultProperties();
        props.setMaxTotalConnections(77);
        PooledRestClientFactory factory = factory(props);

        // When:
        PoolingHttpClientConnectionManager cm = factory.buildConnectionManager();

        // Then:
        assertThat(cm.getMaxTotal()).isEqualTo(77);
    }

    @Test
    void shouldApplyMaxPerRouteConnectionsTest() {
        // Given:
        PooledHttpClientProperties props = defaultProperties();
        props.setMaxConnectionsPerRoute(13);
        PooledRestClientFactory factory = factory(props);

        // When:
        PoolingHttpClientConnectionManager cm = factory.buildConnectionManager();

        // Then:
        assertThat(cm.getDefaultMaxPerRoute()).isEqualTo(13);
    }

    @Test
    void shouldNotThrowWithCustomPoolSizeTest() {
        // Given:
        PooledHttpClientProperties props = defaultProperties();
        props.setMaxTotalConnections(5);
        props.setMaxConnectionsPerRoute(2);
        PooledRestClientFactory factory = factory(props);

        // When / Then:
        assertThat(factory.createClient("small-pool", "https://api.example.com")).isNotNull();
    }

    @Test
    void shouldNotThrowWithCustomTimeoutsTest() {
        // Given:
        PooledHttpClientProperties props = defaultProperties();
        props.setConnectTimeout(Duration.ofSeconds(1));
        props.setResponseTimeout(Duration.ofSeconds(10));
        props.setConnectionRequestTimeout(Duration.ofSeconds(2));
        PooledRestClientFactory factory = factory(props);

        // When / Then:
        assertThat(factory.createClient("fast-timeouts", "https://api.example.com")).isNotNull();
    }

    @Test
    void shouldReturnIndependentClientsTest() {
        // Given:
        PooledRestClientFactory factory = factory(defaultProperties());

        // When:
        RestClient c1 = factory.createClient("svc-a", "https://a.example.com");
        RestClient c2 = factory.createClient("svc-b", "https://b.example.com");

        // Then:
        assertThat(c1).isNotSameAs(c2);
    }
}
