package PACKAGE_REPLACE_ME.observability.external;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.function.Supplier;

/**
 * Records low-cardinality latency and outcome metrics for SDK-managed or other
 * external calls that do not pass through a Spring HTTP interceptor.
 */
@Component
@RequiredArgsConstructor
public class ExternalCallTimer {

    /** Shared timer name for instrumented third-party calls. */
    public static final String METRIC_NAME = "external.client.requests";

    private final MeterRegistry meterRegistry;

    /**
     * Times an external call, records a coarse outcome, and preserves its result
     * or failure.
     *
     * @param client fixed low-cardinality logical client name
     * @param operation fixed low-cardinality operation name
     * @param call external call to invoke
     * @param <T> result type
     * @return result returned by the call
     */
    public <T> T record(String client, String operation, Supplier<T> call) {
        Timer.Sample sample = Timer.start(meterRegistry);
        String outcome = "success";
        try {
            return call.get();
        } catch (RuntimeException | Error failure) {
            outcome = "error";
            throw failure;
        } finally {
            stop(sample, client, operation, outcome);
        }
    }

    /**
     * Times a void-returning external call.
     *
     * @param client fixed low-cardinality logical client name
     * @param operation fixed low-cardinality operation name
     * @param call external call to invoke
     */
    public void record(String client, String operation, Runnable call) {
        record(client, operation, () -> {
            call.run();
            return null;
        });
    }

    /**
     * Stops a sample using the shared external-client metric schema.
     *
     * @param sample running timer sample
     * @param client fixed logical client name
     * @param operation fixed operation name
     * @param outcome coarse outcome
     */
    void stop(Timer.Sample sample, String client, String operation, String outcome) {
        sample.stop(Timer.builder(METRIC_NAME)
            .tag("client", client)
            .tag("operation", operation)
            .tag("outcome", outcome)
            .register(meterRegistry));
    }
}
