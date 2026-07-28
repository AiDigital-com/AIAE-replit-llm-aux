package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleDriveClient;
import java.util.List;

/**
 * Deterministic Google Drive stub for local development and tests.
 */
public class GoogleDriveStubClient implements GoogleDriveClient {

    @Override
    public List<String> listFiles(String folderId) {
        return List.of(folderId + "-file-1", folderId + "-file-2");
    }
}
