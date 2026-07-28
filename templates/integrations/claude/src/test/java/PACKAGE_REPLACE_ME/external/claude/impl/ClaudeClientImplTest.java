package PACKAGE_REPLACE_ME.external.claude.impl;

import PACKAGE_REPLACE_ME.external.claude.ClaudeExternalException;
import PACKAGE_REPLACE_ME.external.claude.config.ClaudeProperties;
import PACKAGE_REPLACE_ME.external.claude.model.ClaudeContentBlock;
import PACKAGE_REPLACE_ME.external.claude.model.ClaudeResponse;
import PACKAGE_REPLACE_ME.external.common.http.PooledRestClientFactory;
import PACKAGE_REPLACE_ME.external.common.http.config.PooledHttpClientProperties;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.zalando.logbook.Logbook;

import java.io.IOException;
import java.time.Duration;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;

/**
 * Unit tests for {@link ClaudeClientImpl}.
 *
 * <p>{@code complete()} tests use a Mockito spy to stub {@code extractText()}
 * and verify HTTP-layer behaviour in isolation. {@code extractText()} is covered
 * separately so each concern has a single reason to fail.
 */
class ClaudeClientImplTest {

    private static final String VALID_API_RESPONSE = """
            {
              "id": "msg_01",
              "type": "message",
              "content": [{"type": "text", "text": "Hello from Claude"}]
            }
            """;

    private MockWebServer server;
    private ClaudeProperties properties;
    private PooledRestClientFactory factory;

    @BeforeEach
    void setUp() throws IOException {
        server = new MockWebServer();
        server.start();

        properties = new ClaudeProperties();
        properties.setEnabled(true);
        properties.setBaseUrl(server.url("/").toString().replaceAll("/$", ""));
        properties.setApiKey("test-api-key-secret");
        properties.setApiVersion("2023-06-01");
        properties.setModel("claude-3-5-sonnet-20241022");
        properties.setMaxTokens(512);

        PooledHttpClientProperties httpProps = new PooledHttpClientProperties();
        httpProps.setConnectTimeout(Duration.ofSeconds(5));
        httpProps.setResponseTimeout(Duration.ofSeconds(10));
        httpProps.setConnectionRequestTimeout(Duration.ofSeconds(5));
        httpProps.setKeepAliveDuration(Duration.ofSeconds(60));
        httpProps.setIdleEvictionDuration(Duration.ofSeconds(30));
        factory = new PooledRestClientFactory(
            Logbook.builder().build(), new SimpleMeterRegistry(), httpProps);
    }

    @AfterEach
    void tearDown() throws IOException {
        server.shutdown();
    }

    // ── complete() — HTTP wiring (extractText stubbed via spy) ─────────────

    @Test
    void shouldSendPostToMessagesEndpointTest() throws InterruptedException {
        // Given:
        server.enqueue(new MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "application/json")
                .setBody(VALID_API_RESPONSE));
        ClaudeClientImpl spy = Mockito.spy(new ClaudeClientImpl(properties, factory));
        doReturn("stubbed").when(spy).extractText(any());

        // When:
        spy.complete("sys", "msg");

        // Then:
        RecordedRequest request = server.takeRequest();
        assertThat(request.getMethod()).isEqualTo("POST");
        assertThat(request.getPath()).isEqualTo("/v1/messages");
    }

    @Test
    void shouldSendRequiredAnthropicHeadersTest() throws InterruptedException {
        // Given:
        server.enqueue(new MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "application/json")
                .setBody(VALID_API_RESPONSE));
        ClaudeClientImpl spy = Mockito.spy(new ClaudeClientImpl(properties, factory));
        doReturn("stubbed").when(spy).extractText(any());

        // When:
        spy.complete("sys", "msg");

        // Then:
        RecordedRequest request = server.takeRequest();
        assertThat(request.getHeader("x-api-key")).isEqualTo("test-api-key-secret");
        assertThat(request.getHeader("anthropic-version")).isEqualTo("2023-06-01");
        assertThat(request.getHeader("Content-Type")).contains("application/json");
    }

    @Test
    void shouldSendCorrectRequestBodyJsonTest() throws InterruptedException {
        // Given:
        server.enqueue(new MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "application/json")
                .setBody(VALID_API_RESPONSE));
        ClaudeClientImpl spy = Mockito.spy(new ClaudeClientImpl(properties, factory));
        doReturn("stubbed").when(spy).extractText(any());

        // When:
        spy.complete("You are helpful", "Explain gravity");

        // Then:
        RecordedRequest request = server.takeRequest();
        String body = request.getBody().readUtf8();
        assertThat(body).contains("\"model\":\"claude-3-5-sonnet-20241022\"");
        assertThat(body).contains("\"max_tokens\":512");
        assertThat(body).contains("\"system\":\"You are helpful\"");
        assertThat(body).contains("\"content\":\"Explain gravity\"");
    }

    @Test
    void shouldThrowClaudeExternalExceptionOnHttp4xxTest() {
        // Given:
        server.enqueue(new MockResponse()
                .setResponseCode(401)
                .setHeader("Content-Type", "application/json")
                .setBody("{\"error\":{\"type\":\"authentication_error\"}}"));
        ClaudeClientImpl client = new ClaudeClientImpl(properties, factory);

        // When / Then:
        assertThatThrownBy(() -> client.complete("sys", "msg"))
                .isInstanceOf(ClaudeExternalException.class)
                .satisfies(ex -> assertThat(((ClaudeExternalException) ex).getHttpStatus())
                        .isEqualTo(401));
    }

    @Test
    void shouldThrowClaudeExternalExceptionOnHttp5xxTest() {
        // Given:
        server.enqueue(new MockResponse()
                .setResponseCode(500)
                .setHeader("Content-Type", "application/json")
                .setBody("{\"error\":\"internal server error\"}"));
        ClaudeClientImpl client = new ClaudeClientImpl(properties, factory);

        // When / Then:
        assertThatThrownBy(() -> client.complete("sys", "msg"))
                .isInstanceOf(ClaudeExternalException.class)
                .satisfies(ex -> assertThat(((ClaudeExternalException) ex).getHttpStatus())
                        .isEqualTo(500));
    }

    @Test
    void shouldThrowClaudeExternalExceptionOnMalformedJsonTest() {
        // Given:
        server.enqueue(new MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "application/json")
                .setBody("not-json{{}}"));
        ClaudeClientImpl client = new ClaudeClientImpl(properties, factory);

        // When / Then:
        assertThatThrownBy(() -> client.complete("sys", "msg"))
                .isInstanceOf(ClaudeExternalException.class);
    }

    @Test
    void shouldNotIncludeApiKeyInExceptionMessageTest() {
        // Given:
        server.enqueue(new MockResponse()
                .setResponseCode(401)
                .setHeader("Content-Type", "application/json")
                .setBody("{\"error\":\"unauthorized\"}"));
        ClaudeClientImpl client = new ClaudeClientImpl(properties, factory);

        // When / Then:
        assertThatThrownBy(() -> client.complete("sys", "msg"))
                .isInstanceOf(ClaudeExternalException.class)
                .satisfies(ex -> {
                    assertThat(ex.getMessage()).doesNotContain("test-api-key-secret");
                    if (ex.getCause() != null) {
                        assertThat(ex.getCause().getMessage())
                                .doesNotContain("test-api-key-secret");
                    }
                });
    }

    // ── extractText() — covered in isolation ───────────────────────────────

    @Test
    void shouldExtractTextFromFirstTextBlockTest() {
        // Given:
        ClaudeClientImpl client = new ClaudeClientImpl(properties, factory);
        ClaudeContentBlock block = new ClaudeContentBlock("text", "Hello world");
        ClaudeResponse response = new ClaudeResponse("msg_01", "message", List.of(block));

        // When:
        String result = client.extractText(response);

        // Then:
        assertThat(result).isEqualTo("Hello world");
    }

    @Test
    void shouldThrowWhenResponseContentIsNullTest() {
        // Given:
        ClaudeClientImpl client = new ClaudeClientImpl(properties, factory);
        ClaudeResponse response = new ClaudeResponse("msg_01", "message", null);

        // When / Then:
        assertThatThrownBy(() -> client.extractText(response))
                .isInstanceOf(ClaudeExternalException.class)
                .hasMessageContaining("empty content");
    }

    @Test
    void shouldThrowWhenResponseContentIsEmptyTest() {
        // Given:
        ClaudeClientImpl client = new ClaudeClientImpl(properties, factory);
        ClaudeResponse response = new ClaudeResponse("msg_01", "message", List.of());

        // When / Then:
        assertThatThrownBy(() -> client.extractText(response))
                .isInstanceOf(ClaudeExternalException.class)
                .hasMessageContaining("empty content");
    }

    @Test
    void shouldThrowWhenNoTextBlockPresentTest() {
        // Given:
        ClaudeClientImpl client = new ClaudeClientImpl(properties, factory);
        ClaudeContentBlock nonText = new ClaudeContentBlock("tool_use", null);
        ClaudeResponse response = new ClaudeResponse("msg_01", "message", List.of(nonText));

        // When / Then:
        assertThatThrownBy(() -> client.extractText(response))
                .isInstanceOf(ClaudeExternalException.class)
                .hasMessageContaining("no text content block");
    }
}
