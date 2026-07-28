package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleSlidesClient;

/**
 * Deterministic Google Slides stub for local development and tests.
 */
public class GoogleSlidesStubClient implements GoogleSlidesClient {

    @Override
    public String getPresentationTitle(String presentationId) {
        return "[STUB] Google Slides presentation " + presentationId;
    }
}
