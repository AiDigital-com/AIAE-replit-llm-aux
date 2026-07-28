package PACKAGE_REPLACE_ME.observability.external;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpRequest;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.client.ClientHttpRequestExecution;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.ClientHttpResponse;

import java.io.IOException;

/**
 * Records low-cardinality latency and outcome metrics for third-party Spring
 * HTTP clients without tagging request paths, query values, user data, or host
 * names supplied at runtime.
 */
@RequiredArgsConstructor
public class ExternalClientMetricsInterceptor implements ClientHttpRequestInterceptor {

    private final String clientName;
    private final MeterRegistry meterRegistry;

    /**
     * Times the remaining HTTP execution chain and records its coarse outcome.
     *
     * @param request outbound request
     * @param body outbound body
     * @param execution remaining interceptor/execution chain
     * @return downstream response without modification
     * @throws IOException propagated downstream I/O failure
     */
    @Override
    public ClientHttpResponse intercept(HttpRequest request, byte[] body,
                                        ClientHttpRequestExecution execution)
            throws IOException {
        Timer.Sample sample = Timer.start(meterRegistry);
        String outcome = "io_error";
        try {
            ClientHttpResponse response = execution.execute(request, body);
            outcome = classifyOutcome(response.getStatusCode());
            return response;
        } catch (RuntimeException failure) {
            outcome = "runtime_error";
            throw failure;
        } finally {
            sample.stop(Timer.builder(ExternalCallTimer.METRIC_NAME)
                .tag("client", clientName)
                .tag("operation", request.getMethod().name())
                .tag("outcome", outcome)
                .register(meterRegistry));
        }
    }

    /**
     * Maps an HTTP status to a bounded outcome tag.
     *
     * @param status response status
     * @return success, client_error, or server_error
     */
    String classifyOutcome(HttpStatusCode status) {
        if (status.is5xxServerError()) {
            return "server_error";
        }
        if (status.is4xxClientError()) {
            return "client_error";
        }
        return "success";
    }
}
