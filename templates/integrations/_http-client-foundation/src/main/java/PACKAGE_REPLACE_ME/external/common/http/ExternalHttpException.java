package PACKAGE_REPLACE_ME.external.common.http;

/**
 * Runtime exception wrapping HTTP-level errors from external services.
 *
 * <p>Carries the HTTP status code and raw response body so that callers
 * can make routing decisions (retry, fallback, surface an appropriate
 * application error) without re-parsing raw HTTP details.
 */
public class ExternalHttpException extends RuntimeException {

    private final int statusCode;
    private final String responseBody;

    /**
     * Constructs an exception from a non-2xx HTTP response.
     *
     * @param message     human-readable description including service name
     * @param statusCode  HTTP response status code
     * @param responseBody raw response body (may be empty)
     */
    public ExternalHttpException(String message, int statusCode, String responseBody) {
        super(message);
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    /**
     * Constructs an exception wrapping a lower-level I/O or timeout cause.
     *
     * @param message human-readable description
     * @param cause   underlying exception
     */
    public ExternalHttpException(String message, Throwable cause) {
        super(message, cause);
        this.statusCode = -1;
        this.responseBody = "";
    }

    /**
     * Returns the HTTP status code returned by the external service.
     * Returns {@code -1} when the failure occurred before a response was received.
     *
     * @return HTTP status code or {@code -1}
     */
    public int getStatusCode() {
        return statusCode;
    }

    /**
     * Returns the raw response body from the external service.
     * May be empty when the failure occurred before a response body was received.
     *
     * @return response body, never {@code null}
     */
    public String getResponseBody() {
        return responseBody;
    }
}
