package PACKAGE_REPLACE_ME.external.googleworkspace;

/**
 * Runtime exception signalling a failure when calling Google Workspace APIs.
 *
 * <p>Covers API errors, credential failures, and malformed responses.
 * Credentials are never included in the message or cause.
 */
public class GoogleWorkspaceExternalException extends RuntimeException {

    /**
     * Constructs an exception with a descriptive message.
     *
     * @param message human-readable description (must not contain credentials)
     */
    public GoogleWorkspaceExternalException(String message) {
        super(message);
    }

    /**
     * Constructs an exception wrapping an underlying cause.
     *
     * @param message human-readable description
     * @param cause   underlying exception
     */
    public GoogleWorkspaceExternalException(String message, Throwable cause) {
        super(message, cause);
    }
}
