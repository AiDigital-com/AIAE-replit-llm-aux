package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleDocsClient;

/**
 * Deterministic Google Docs stub for local development and tests.
 */
public class GoogleDocsStubClient implements GoogleDocsClient {

    @Override
    public String getDocumentContent(String documentId) {
        return "[STUB] Google Docs document content for " + documentId;
    }
}
