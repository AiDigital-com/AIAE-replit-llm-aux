package PACKAGE_REPLACE_ME.external.googleworkspace;

import java.util.List;

/**
 * Narrow application-facing interface for the Google Drive API.
 *
 * <p>Credentials are sourced from properties only and are never logged.
 *
 * @see GoogleWorkspaceExternalException for error semantics
 */
public interface GoogleDriveClient {

    /**
     * Lists the IDs of files directly contained in a Google Drive folder.
     *
     * @param folderId the Google Drive folder ID (from the folder URL)
     * @return list of file IDs in the folder; empty list when the folder is empty
     * @throws GoogleWorkspaceExternalException on API error or credential failure
     */
    List<String> listFiles(String folderId);
}
