package PACKAGE_REPLACE_ME.external.openai.impl;

import PACKAGE_REPLACE_ME.external.common.http.PooledRestClientFactory;
import PACKAGE_REPLACE_ME.external.common.http.config.PooledHttpClientProperties;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import PACKAGE_REPLACE_ME.external.openai.OpenAiExternalException;
import PACKAGE_REPLACE_ME.external.openai.config.OpenAiProperties;
import PACKAGE_REPLACE_ME.external.openai.model.OpenAiChatResponse;
import PACKAGE_REPLACE_ME.external.openai.model.OpenAiMessage;
import PACKAGE_REPLACE_ME.external.openai.model.OpenAiResponsesResponse;
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

class OpenAiClientImplTest {

    private static final String VALID_RESPONSES_BODY = """
            {
              "output": [
                {
                  "type": "message",
                  "content": [
                    {"type": "output_text", "text": "Hello from GPT"}
                  ]
                }
              ]
            }
            """;

    private static final String VALID_CHAT_BODY = """
            {
              "id": "chatcmpl-001",
              "choices": [
                {
                  "message": {"role": "assistant", "content": "Hello from GPT"},
                  "finish_reason": "stop"
                }
              ]
            }
            """;

    private MockWebServer server;
    private OpenAiProperties properties;
    private PooledRestClientFactory factory;

    @BeforeEach
    void setUp() throws IOException {
        server = new MockWebServer();
        server.start();

        properties = new OpenAiProperties();
        properties.setEnabled(true);
        properties.setBaseUrl(server.url("/").toString().replaceAll("/$", ""));
        properties.setApiKey("sk-test-secret-key");
        properties.setModel("gpt-4o");
        properties.setMaxTokens(256);

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
        factory.destroy();
        server.shutdown();
    }

    @Test
    void shouldSendPostToResponsesEndpointByDefaultTest() throws InterruptedException {
        server.enqueue(new MockResponse()
            .setResponseCode(200)
            .setHeader("Content-Type", "application/json")
            .setBody(VALID_RESPONSES_BODY));
        OpenAiClientImpl spy = Mockito.spy(new OpenAiClientImpl(properties, factory));
        doReturn("stubbed").when(spy).extractResponsesText(any());

        spy.complete("sys", "msg");

        RecordedRequest request = server.takeRequest();
        assertThat(request.getMethod()).isEqualTo("POST");
        assertThat(request.getPath()).isEqualTo("/v1/responses");
    }

    @Test
    void shouldSendPostToChatCompletionsWhenLegacyModeTest() throws InterruptedException {
        properties.setApiMode("chat-completions");
        server.enqueue(new MockResponse()
            .setResponseCode(200)
            .setHeader("Content-Type", "application/json")
            .setBody(VALID_CHAT_BODY));
        OpenAiClientImpl spy = Mockito.spy(new OpenAiClientImpl(properties, factory));
        doReturn("stubbed").when(spy).extractChatText(any());

        spy.complete("sys", "msg");

        RecordedRequest request = server.takeRequest();
        assertThat(request.getPath()).isEqualTo("/v1/chat/completions");
    }

    @Test
    void shouldSendBearerAuthorizationHeaderTest() throws InterruptedException {
        server.enqueue(new MockResponse()
            .setResponseCode(200)
            .setHeader("Content-Type", "application/json")
            .setBody(VALID_RESPONSES_BODY));
        OpenAiClientImpl spy = Mockito.spy(new OpenAiClientImpl(properties, factory));
        doReturn("stubbed").when(spy).extractResponsesText(any());

        spy.complete("sys", "msg");

        RecordedRequest request = server.takeRequest();
        assertThat(request.getHeader("Authorization")).isEqualTo("Bearer sk-test-secret-key");
    }

    @Test
    void shouldSendResponsesRequestBodyTest() throws InterruptedException {
        server.enqueue(new MockResponse()
            .setResponseCode(200)
            .setHeader("Content-Type", "application/json")
            .setBody(VALID_RESPONSES_BODY));
        OpenAiClientImpl spy = Mockito.spy(new OpenAiClientImpl(properties, factory));
        doReturn("stubbed").when(spy).extractResponsesText(any());

        spy.complete("You are a helper", "What is 2+2?");

        String body = server.takeRequest().getBody().readUtf8();
        assertThat(body).contains("\"model\":\"gpt-4o\"");
        assertThat(body).contains("\"max_output_tokens\":256");
        assertThat(body).contains("\"role\":\"system\"");
        assertThat(body).contains("\"role\":\"user\"");
    }

    @Test
    void shouldThrowOpenAiExternalExceptionOnHttp4xxTest() {
        server.enqueue(new MockResponse()
            .setResponseCode(401)
            .setHeader("Content-Type", "application/json")
            .setBody("{\"error\":{\"message\":\"Invalid API key\"}}"));
        OpenAiClientImpl client = new OpenAiClientImpl(properties, factory);

        assertThatThrownBy(() -> client.complete("sys", "msg"))
            .isInstanceOf(OpenAiExternalException.class)
            .satisfies(ex -> assertThat(((OpenAiExternalException) ex).getHttpStatus()).isEqualTo(401));
    }

    @Test
    void shouldExtractTextFromResponsesOutputTest() {
        OpenAiClientImpl client = new OpenAiClientImpl(properties, factory);
        OpenAiResponsesResponse response = new OpenAiResponsesResponse(List.of(
            new OpenAiResponsesResponse.OutputItem(
                "message",
                List.of(new OpenAiResponsesResponse.ContentPart("output_text", "Hello world")))));

        assertThat(client.extractResponsesText(response)).isEqualTo("Hello world");
    }

    @Test
    void shouldExtractTextFromFirstChatChoiceTest() {
        OpenAiClientImpl client = new OpenAiClientImpl(properties, factory);
        OpenAiChatResponse.Choice choice = new OpenAiChatResponse.Choice(
            new OpenAiMessage("assistant", "Hello world"), "stop");
        OpenAiChatResponse response = new OpenAiChatResponse("id-1", List.of(choice));

        assertThat(client.extractChatText(response)).isEqualTo("Hello world");
    }

    @Test
    void shouldThrowWhenResponsesOutputEmptyTest() {
        OpenAiClientImpl client = new OpenAiClientImpl(properties, factory);
        assertThatThrownBy(() -> client.extractResponsesText(new OpenAiResponsesResponse(List.of())))
            .isInstanceOf(OpenAiExternalException.class)
            .hasMessageContaining("empty output");
    }
}
