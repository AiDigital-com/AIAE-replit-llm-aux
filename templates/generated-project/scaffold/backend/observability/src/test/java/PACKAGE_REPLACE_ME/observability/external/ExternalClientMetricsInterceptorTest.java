package PACKAGE_REPLACE_ME.observability.external;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.ClientHttpRequestExecution;
import org.springframework.mock.http.client.MockClientHttpResponse;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ExternalClientMetricsInterceptorTest {

    @Test
    void shouldRecordSuccessWithBoundedTagsTest() throws IOException {
        assertRecordedOutcome(HttpStatus.OK, "success");
    }

    @Test
    void shouldRecordClientErrorTest() throws IOException {
        assertRecordedOutcome(HttpStatus.BAD_REQUEST, "client_error");
    }

    @Test
    void shouldRecordServerErrorTest() throws IOException {
        assertRecordedOutcome(HttpStatus.SERVICE_UNAVAILABLE, "server_error");
    }

    @Test
    void shouldRecordIoErrorAndRethrowTest() throws IOException {
        // Given:
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        ExternalClientMetricsInterceptor interceptor =
            new ExternalClientMetricsInterceptor("openai", registry);
        HttpRequest request = request();
        ClientHttpRequestExecution execution = mock(ClientHttpRequestExecution.class);
        when(execution.execute(request, new byte[0])).thenThrow(new IOException("offline"));

        // When / Then:
        assertThatThrownBy(() -> interceptor.intercept(request, new byte[0], execution))
            .isInstanceOf(IOException.class);
        assertTimerCount(registry, "io_error");
    }

    @Test
    void shouldRecordRuntimeErrorAndRethrowTest() throws IOException {
        // Given:
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        ExternalClientMetricsInterceptor interceptor =
            new ExternalClientMetricsInterceptor("openai", registry);
        HttpRequest request = request();
        ClientHttpRequestExecution execution = mock(ClientHttpRequestExecution.class);
        when(execution.execute(request, new byte[0]))
            .thenThrow(new IllegalStateException("invalid client state"));

        // When / Then:
        assertThatThrownBy(() -> interceptor.intercept(request, new byte[0], execution))
            .isInstanceOf(IllegalStateException.class);
        assertTimerCount(registry, "runtime_error");
    }

    private void assertRecordedOutcome(HttpStatus status, String outcome) throws IOException {
        // Given:
        SimpleMeterRegistry registry = new SimpleMeterRegistry();
        ExternalClientMetricsInterceptor interceptor =
            new ExternalClientMetricsInterceptor("openai", registry);
        HttpRequest request = request();
        ClientHttpRequestExecution execution = mock(ClientHttpRequestExecution.class);
        when(execution.execute(request, new byte[0]))
            .thenReturn(new MockClientHttpResponse(new byte[0], status));

        // When:
        interceptor.intercept(request, new byte[0], execution);

        // Then:
        assertTimerCount(registry, outcome);
    }

    private HttpRequest request() {
        HttpRequest request = mock(HttpRequest.class);
        when(request.getMethod()).thenReturn(HttpMethod.POST);
        return request;
    }

    private void assertTimerCount(SimpleMeterRegistry registry, String outcome) {
        assertThat(registry.get(ExternalCallTimer.METRIC_NAME)
            .tags("client", "openai", "operation", "POST", "outcome", outcome)
            .timer().count()).isEqualTo(1);
    }
}
