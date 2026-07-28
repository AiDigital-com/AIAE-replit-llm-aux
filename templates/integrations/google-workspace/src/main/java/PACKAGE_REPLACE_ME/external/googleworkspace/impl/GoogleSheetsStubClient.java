package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleSheetsClient;
import java.util.List;

/**
 * Deterministic Google Sheets stub for local development and tests.
 */
public class GoogleSheetsStubClient implements GoogleSheetsClient {

    @Override
    public List<List<String>> readSheet(String spreadsheetId, String range) {
        return List.of(
            List.of("[STUB]", spreadsheetId),
            List.of("range", range)
        );
    }
}
