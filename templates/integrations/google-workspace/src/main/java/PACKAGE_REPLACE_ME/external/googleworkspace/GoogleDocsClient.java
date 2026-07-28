package PACKAGE_REPLACE_ME.external.googleworkspace;

/**
 * Narrow application-facing interface for the Google Docs API.
 *
 * <p>Credentials are sourced from properties only and are never logged.
 *
 * @see GoogleWorkspaceExternalException for error semantics
 */
public interface GoogleDocsClient {

    /**
     * Retrieves the plain-text content of a Google Docs document.
     *
     * @param documentId the Google Docs document ID (from the document URL)
     * @return the document's plain-text body content
     * @throws GoogleWorkspaceExternalException on API error or credential failure
     */
    String getDocumentContent(String documentId);
}
