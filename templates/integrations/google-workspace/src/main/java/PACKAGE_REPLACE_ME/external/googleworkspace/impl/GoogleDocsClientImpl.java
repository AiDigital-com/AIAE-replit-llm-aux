package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleDocsClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleWorkspaceExternalException;

import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.docs.v1.Docs;
import com.google.api.services.docs.v1.model.Document;
import com.google.api.services.docs.v1.model.StructuralElement;
import com.google.auth.http.HttpCredentialsAdapter;
import com.google.auth.oauth2.GoogleCredentials;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.List;

/**
 * Production implementation of {@link GoogleDocsClient} backed by the Google
 * Docs v1 API.
 *
 * <p>Credentials are loaded from a raw service-account JSON string provided at
 * construction time. The credential string is never logged.
 *
 * <p>The Google API quota user is the service account. All calls are
 * synchronous on the calling thread; delegate to a thread pool or
 * {@code @Async} bean in the service layer when needed.
 */
public class GoogleDocsClientImpl implements GoogleDocsClient {

    private static final Logger LOG = LoggerFactory.getLogger(GoogleDocsClientImpl.class);
    private static final String APPLICATION_NAME = "AI Digital App";
    private static final List<String> SCOPES =
        Collections.singletonList("https://www.googleapis.com/auth/documents.readonly");

    private final Docs docs;

    /**
     * Package-private constructor for unit testing — accepts a pre-built service.
     *
     * @param docs pre-built Google Docs API service instance
     */
    GoogleDocsClientImpl(com.google.api.services.docs.v1.Docs docs) {
        this.docs = docs;
    }

    /**
     * Constructs the client and authenticates with the given service-account JSON.
     *
     * @param credentialsJson raw service-account JSON key string
     * @throws GoogleWorkspaceExternalException when credentials cannot be loaded or the
     *         transport cannot be initialized
     */
    public GoogleDocsClientImpl(String credentialsJson) {
        try {
            GoogleCredentials credentials = GoogleCredentials
                .fromStream(new ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8)))
                .createScoped(SCOPES);
            this.docs = new Docs.Builder(
                    GoogleNetHttpTransport.newTrustedTransport(),
                    GsonFactory.getDefaultInstance(),
                    new HttpCredentialsAdapter(credentials))
                .setApplicationName(APPLICATION_NAME)
                .build();
        } catch (Exception ex) {
            throw new GoogleWorkspaceExternalException(
                "Failed to initialize Google Docs client — check credentials JSON", ex);
        }
    }

    /**
     * {@inheritDoc}
     *
     * <p>Reads the document body elements and concatenates all text runs into a
     * single string. Structural elements with no inline text (e.g. tables,
     * horizontal rules) are skipped.
     */
    @Override
    public String getDocumentContent(String documentId) {
        LOG.debug("Fetching Google Docs document: id={}", documentId);
        try {
            Document document = docs.documents().get(documentId).execute();
            return extractText(document);
        } catch (IOException ex) {
            throw new GoogleWorkspaceExternalException(
                "Failed to fetch Google Docs document id=" + documentId, ex);
        }
    }

    /**
     * Extracts plain text from a Google Docs document by concatenating all text runs.
     *
     * @param document the fetched Google Docs document
     * @return concatenated plain text; empty string when the document body is absent
     */
    String extractText(Document document) {
        if (document.getBody() == null || document.getBody().getContent() == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (StructuralElement element : document.getBody().getContent()) {
            if (element.getParagraph() == null) {
                continue;
            }
            element.getParagraph().getElements().forEach(pe -> {
                if (pe.getTextRun() != null && pe.getTextRun().getContent() != null) {
                    sb.append(pe.getTextRun().getContent());
                }
            });
        }
        return sb.toString();
    }
}
