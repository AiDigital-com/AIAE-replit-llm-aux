package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleSheetsClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleWorkspaceExternalException;

import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.sheets.v4.Sheets;
import com.google.api.services.sheets.v4.model.ValueRange;
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
 * Production implementation of {@link GoogleSheetsClient} backed by the Google
 * Sheets v4 API.
 *
 * <p>Returned cell values are strings. The API's {@code FORMATTED_VALUE} render
 * option is used so date and number formatting from the sheet is preserved.
 */
public class GoogleSheetsClientImpl implements GoogleSheetsClient {

    private static final Logger LOG = LoggerFactory.getLogger(GoogleSheetsClientImpl.class);
    private static final String APPLICATION_NAME = "AI Digital App";
    private static final List<String> SCOPES =
        Collections.singletonList("https://www.googleapis.com/auth/spreadsheets.readonly");

    private final Sheets sheets;

    /**
     * Package-private constructor for unit testing — accepts a pre-built service.
     *
     * @param sheets pre-built Google Sheets API service instance
     */
    GoogleSheetsClientImpl(com.google.api.services.sheets.v4.Sheets sheets) {
        this.sheets = sheets;
    }

    /**
     * Constructs the client and authenticates with the given service-account JSON.
     *
     * @param credentialsJson raw service-account JSON key string
     * @throws GoogleWorkspaceExternalException when initialization fails
     */
    public GoogleSheetsClientImpl(String credentialsJson) {
        try {
            GoogleCredentials credentials = GoogleCredentials
                .fromStream(new ByteArrayInputStream(credentialsJson.getBytes(StandardCharsets.UTF_8)))
                .createScoped(SCOPES);
            this.sheets = new Sheets.Builder(
                    GoogleNetHttpTransport.newTrustedTransport(),
                    GsonFactory.getDefaultInstance(),
                    new HttpCredentialsAdapter(credentials))
                .setApplicationName(APPLICATION_NAME)
                .build();
        } catch (Exception ex) {
            throw new GoogleWorkspaceExternalException(
                "Failed to initialize Google Sheets client — check credentials JSON", ex);
        }
    }

    /**
     * {@inheritDoc}
     *
     * <p>Reads the given A1-notation range. Trailing empty cells within a row
     * are included; trailing empty rows at the end of the range are omitted
     * by the API.
     */
    @Override
    public List<List<String>> readSheet(String spreadsheetId, String range) {
        LOG.debug("Reading Google Sheets range: spreadsheet={}, range={}", spreadsheetId, range);
        try {
            ValueRange response = sheets.spreadsheets().values()
                .get(spreadsheetId, range)
                .setValueRenderOption("FORMATTED_VALUE")
                .execute();
            List<List<Object>> raw = response.getValues();
            if (raw == null) {
                return Collections.emptyList();
            }
            return raw.stream()
                .map(row -> row.stream()
                    .map(cell -> cell == null ? "" : String.valueOf(cell))
                    .collect(Collectors.toList()))
                .collect(Collectors.toList());
        } catch (IOException ex) {
            throw new GoogleWorkspaceExternalException(
                "Failed to read Google Sheets spreadsheet=" + spreadsheetId
                    + " range=" + range, ex);
        }
    }
}
