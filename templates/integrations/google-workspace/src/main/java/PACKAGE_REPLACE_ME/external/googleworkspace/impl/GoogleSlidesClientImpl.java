package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleSlidesClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleWorkspaceExternalException;

import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.slides.v1.Slides;
import com.google.api.services.slides.v1.model.Presentation;
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
 * Production implementation of {@link GoogleSlidesClient} backed by the Google
 * Slides v1 API.
 */
public class GoogleSlidesClientImpl implements GoogleSlidesClient {

    private static final Logger LOG = LoggerFactory.getLogger(GoogleSlidesClientImpl.class);
    private static final String APPLICATION_NAME = "AI Digital App";
    private static final List<String> SCOPES =
        Collections.singletonList("https://www.googleapis.com/auth/presentations.readonly");

    private final Slides slides;

    /**
     * Package-private constructor for unit testing — accepts a pre-built service.
     *
     * @param slides pre-built Google Slides API service instance
     */
    GoogleSlidesClientImpl(com.google.api.services.slides.v1.Slides slides) {
        this.slides = slides;
    }

    /**
     * Constructs the client and authenticates with the given service-account JSON.
     *
     * @param credentialsJson raw service-account JSON key string
     * @throws GoogleWorkspaceExternalException when initialization fails
     */
    public GoogleSlidesClientImpl(String credentialsJson) {
        try {
            GoogleCredentials credentials = GoogleCredentials
                .fromStream(new ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8)))
                .createScoped(SCOPES);
            this.slides = new Slides.Builder(
                    GoogleNetHttpTransport.newTrustedTransport(),
                    GsonFactory.getDefaultInstance(),
                    new HttpCredentialsAdapter(credentials))
                .setApplicationName(APPLICATION_NAME)
                .build();
        } catch (Exception ex) {
            throw new GoogleWorkspaceExternalException(
                "Failed to initialize Google Slides client — check credentials JSON", ex);
        }
    }

    /**
     * {@inheritDoc}
     */
    @Override
    public String getPresentationTitle(String presentationId) {
        LOG.debug("Fetching Google Slides presentation: id={}", presentationId);
        try {
            Presentation presentation = slides.presentations().get(presentationId).execute();
            String title = presentation.getTitle();
            return title == null ? "" : title;
        } catch (IOException ex) {
            throw new GoogleWorkspaceExternalException(
                "Failed to fetch Google Slides presentation id=" + presentationId, ex);
        }
    }
}
