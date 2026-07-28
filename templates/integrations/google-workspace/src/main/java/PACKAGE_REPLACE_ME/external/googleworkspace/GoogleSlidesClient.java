package PACKAGE_REPLACE_ME.external.googleworkspace;

/**
 * Narrow application-facing interface for the Google Slides API.
 *
 * <p>Credentials are sourced from properties only and are never logged.
 *
 * @see GoogleWorkspaceExternalException for error semantics
 */
public interface GoogleSlidesClient {

    /**
     * Retrieves the title of a Google Slides presentation.
     *
     * @param presentationId the presentation ID (from the presentation URL)
     * @return the presentation title, or an empty string if not set
     * @throws GoogleWorkspaceExternalException on API error or credential failure
     */
    String getPresentationTitle(String presentationId);
}
