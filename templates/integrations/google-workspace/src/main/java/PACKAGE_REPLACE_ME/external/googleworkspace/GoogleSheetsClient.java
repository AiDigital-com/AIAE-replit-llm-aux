package PACKAGE_REPLACE_ME.external.googleworkspace;

import java.util.List;

/**
 * Narrow application-facing interface for the Google Sheets API.
 *
 * <p>Credentials are sourced from properties only and are never logged.
 *
 * @see GoogleWorkspaceExternalException for error semantics
 */
public interface GoogleSheetsClient {

    /**
     * Reads a rectangular range of cells from a Google Sheets spreadsheet.
     *
     * @param spreadsheetId the spreadsheet ID (from the spreadsheet URL)
     * @param range         A1 notation range, e.g. {@code "Sheet1!A1:C10"}
     * @return list of rows, each row being a list of cell values (as strings);
     *         empty rows may be omitted by the Sheets API
     * @throws GoogleWorkspaceExternalException on API error or credential failure
     */
    List<List<String>> readSheet(String spreadsheetId, String range);
}
