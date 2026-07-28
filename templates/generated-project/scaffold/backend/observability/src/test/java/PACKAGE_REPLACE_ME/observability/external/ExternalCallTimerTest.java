package PACKAGE_REPLACE_ME.observability.external;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ExternalCallTimerTest {

    @Test
    void shouldRecordSuccessfulSupplierTest() {
        // Given:
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        ExternalCallTimer timer = new ExternalCallTimer(registry);

        // When:
        String result = timer.record("s3", "getObject", () -> "value");

        // Then:
        assertThat(result).isEqualTo("value");
        assertThat(registry.get(ExternalCallTimer.METRIC_NAME)
            .tags("client", "s3", "operation", "getObject", "outcome", "success")
            .timer().count()).isEqualTo(1);
    }

    @Test
    void shouldRecordAndRethrowFailureTest() {
        // Given:
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        ExternalCallTimer timer = new ExternalCallTimer(registry);

        // When / Then:
        assertThatThrownBy(() -> timer.record("s3", "putObject", () -> {
            throw new IllegalStateException("downstream failed");
        })).isInstanceOf(IllegalStateException.class);
        assertThat(registry.get(ExternalCallTimer.METRIC_NAME)
            .tags("client", "s3", "operation", "putObject", "outcome", "error")
            .timer().count()).isEqualTo(1);
    }

    @Test
    void shouldRecordVoidCallTest() {
        // Given:
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        ExternalCallTimer timer = new ExternalCallTimer(registry);

        // When:
        timer.record("s3", "deleteObject", () -> { });

        // Then:
        assertThat(registry.get(ExternalCallTimer.METRIC_NAME)
            .tags("client", "s3", "operation", "deleteObject", "outcome", "success")
            .timer().count()).isEqualTo(1);
    }
}
