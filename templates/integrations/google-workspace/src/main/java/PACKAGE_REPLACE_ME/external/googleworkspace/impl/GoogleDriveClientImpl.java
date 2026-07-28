package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleDriveClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleWorkspaceExternalException;

import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.drive.Drive;
import com.google.api.services.drive.model.FileList;
import com.google.auth.http.HttpCredentialsAdapter;
import com.google.auth.oauth2.GoogleCredentials;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Production implementation of {@link GoogleDriveClient} backed by the Google
 * Drive v3 API.
 *
 * <p>Credentials are loaded from a raw service-account JSON string. Files
 * returned by the Drive API must be explicitly shared with the service account
 * (or the service account must be a domain-delegated user if impersonation is
 * configured).
 */
public class GoogleDriveClientImpl implements GoogleDriveClient {

    private static final Logger LOG = LoggerFactory.getLogger(GoogleDriveClientImpl.class);
    private static final String APPLICATION_NAME = "AI Digital App";
    private static final List<String> SCOPES =
        Collections.singletonList("https://www.googleapis.com/auth/drive.readonly");

    private final Drive drive;

    /**
     * Package-private constructor for unit testing — accepts a pre-built service.
     *
     * @param drive pre-built Google Drive API service instance
     */
    GoogleDriveClientImpl(com.google.api.services.drive.Drive drive) {
        this.drive = drive;
    }

    /**
     * Constructs the client and authenticates with the given service-account JSON.
     *
     * @param credentialsJson raw service-account JSON key string
     * @throws GoogleWorkspaceExternalException when initialization fails
     */
    public GoogleDriveClientImpl(String credentialsJson) {
        try {
            GoogleCredentials credentials = GoogleCredentials
                .fromStream(new ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8)))
                .createScoped(SCOPES);
            this.drive = new Drive.Builder(
                    GoogleNetHttpTransport.newTrustedTransport(),
                    GsonFactory.getDefaultInstance(),
                    new HttpCredentialsAdapter(credentials))
                .setApplicationName(APPLICATION_NAME)
                .build();
        } catch (Exception ex) {
            throw new GoogleWorkspaceExternalException(
                "Failed to initialize Google Drive client — check credentials JSON", ex);
        }
    }

    /**
     * {@inheritDoc}
     *
     * <p>Lists files whose parent is the given folder ID. Returns only file IDs;
     * callers that need names or MIME types should extend the interface.
     * Pages through results automatically up to 1000 files per folder.
     */
    @Override
    public List<String> listFiles(String folderId) {
        LOG.debug("Listing Google Drive files in folder: id={}", folderId);
        try {
            FileList result = drive.files().list()
                .setQ("'" + folderId + "' in parents and trashed = false")
                .setFields("files(id)")
                .setPageSize(1000)
                .execute();
            if (result.getFiles() == null) {
                return Collections.emptyList();
            }
            return result.getFiles().stream()
                .map(com.google.api.services.drive.model.File::getId)
                .collect(Collectors.toList());
        } catch (IOException ex) {
            throw new GoogleWorkspaceExternalException(
                "Failed to list Google Drive files in folder id=" + folderId, ex);
        }
    }
}
