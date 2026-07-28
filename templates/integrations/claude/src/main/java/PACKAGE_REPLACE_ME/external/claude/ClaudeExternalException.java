package PACKAGE_REPLACE_ME.external.claude;

/**
 * Runtime exception signalling a failure when calling the Anthropic Claude API.
 *
 * <p>Covers non-2xx HTTP responses, network timeouts, and malformed response JSON.
 * The API key is never included in the message or cause.
 */
public class ClaudeExternalException extends RuntimeException {

    private final int httpStatus;
    private final String responseBody;

    /**
     * Constructs an exception from a non-2xx HTTP response.
     *
     * @param message     human-readable description (must not contain the API key)
     * @param httpStatus  HTTP response status code
     * @param responseBody raw response body (may be empty)
     */
    public ClaudeExternalException(String message, int httpStatus, String responseBody) {
        super(message);
        this.httpStatus = httpStatus;
        this.responseBody = responseBody;
    }

    /**
     * Constructs an exception from a network or parse failure.
     *
     * @param message human-readable description
     * @param cause   underlying exception
     */
    public ClaudeExternalException(String message, Throwable cause) {
        super(message, cause);
        this.httpStatus = -1;
        this.responseBody = "";
    }

    /**
     * Returns the HTTP status code from the Claude API response, or {@code -1}
     * when the error occurred before a response was received.
     *
     * @return HTTP status code or {@code -1}
     */
    public int getHttpStatus() {
        return httpStatus;
    }

    /**
     * Returns the raw response body from the Claude API.
     * Empty when the error occurred before a response body was available.
     *
     * @return response body, never {@code null}
     */
    public String getResponseBody() {
        return responseBody;
    }
}
