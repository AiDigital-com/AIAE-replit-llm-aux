package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleWorkspaceExternalException;
import com.google.api.services.sheets.v4.Sheets;
import com.google.api.services.sheets.v4.model.ValueRange;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.io.IOException;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link GoogleSheetsClientImpl} using a mock Sheets service.
 */
@ExtendWith(MockitoExtension.class)
class GoogleSheetsClientImplTest {

    @Mock
    private Sheets sheetsService;

    @Test
    void shouldReturnSheetCellsAsStringsTest() throws IOException {
        // Given:
        Sheets.Spreadsheets spreadsheets = mock(Sheets.Spreadsheets.class);
        Sheets.Spreadsheets.Values values = mock(Sheets.Spreadsheets.Values.class);
        Sheets.Spreadsheets.Values.Get getRequest = mock(Sheets.Spreadsheets.Values.Get.class);

        List<List<Object>> rawData = List.of(
                List.of("Name", "Age"),
                List.of("Alice", "30")
        );
        ValueRange valueRange = new ValueRange().setValues(rawData);

        when(sheetsService.spreadsheets()).thenReturn(spreadsheets);
        when(spreadsheets.values()).thenReturn(values);
        when(values.get(anyString(), anyString())).thenReturn(getRequest);
        when(getRequest.setValueRenderOption(anyString())).thenReturn(getRequest);
        when(getRequest.execute()).thenReturn(valueRange);

        GoogleSheetsClientImpl client = new GoogleSheetsClientImpl(sheetsService);

        // When:
        List<List<String>> result = client.readSheet("spreadsheet-id", "Sheet1!A1:B2");

        // Then:
        assertThat(result).hasSize(2);
        assertThat(result.get(0)).containsExactly("Name", "Age");
        assertThat(result.get(1)).containsExactly("Alice", "30");
    }

    @Test
    void shouldReturnEmptyListWhenSheetHasNoDataTest() throws IOException {
        // Given:
        Sheets.Spreadsheets spreadsheets = mock(Sheets.Spreadsheets.class);
        Sheets.Spreadsheets.Values values = mock(Sheets.Spreadsheets.Values.class);
        Sheets.Spreadsheets.Values.Get getRequest = mock(Sheets.Spreadsheets.Values.Get.class);
        ValueRange valueRange = new ValueRange();

        when(sheetsService.spreadsheets()).thenReturn(spreadsheets);
        when(spreadsheets.values()).thenReturn(values);
        when(values.get(anyString(), anyString())).thenReturn(getRequest);
        when(getRequest.setValueRenderOption(anyString())).thenReturn(getRequest);
        when(getRequest.execute()).thenReturn(valueRange);

        GoogleSheetsClientImpl client = new GoogleSheetsClientImpl(sheetsService);

        // When:
        List<List<String>> result = client.readSheet("spreadsheet-id", "Empty!A1:A1");

        // Then:
        assertThat(result).isEmpty();
    }

    @Test
    void shouldWrapIoExceptionInGoogleWorkspaceExternalExceptionTest() throws IOException {
        // Given:
        Sheets.Spreadsheets spreadsheets = mock(Sheets.Spreadsheets.class);
        Sheets.Spreadsheets.Values values = mock(Sheets.Spreadsheets.Values.class);
        Sheets.Spreadsheets.Values.Get getRequest = mock(Sheets.Spreadsheets.Values.Get.class);

        when(sheetsService.spreadsheets()).thenReturn(spreadsheets);
        when(spreadsheets.values()).thenReturn(values);
        when(values.get(anyString(), anyString())).thenReturn(getRequest);
        when(getRequest.setValueRenderOption(anyString())).thenReturn(getRequest);
        when(getRequest.execute()).thenThrow(new IOException("quota exceeded"));

        GoogleSheetsClientImpl client = new GoogleSheetsClientImpl(sheetsService);

        // When / Then:
        assertThatThrownBy(() -> client.readSheet("ss-fail", "A1:B2"))
                .isInstanceOf(GoogleWorkspaceExternalException.class)
                .hasMessageContaining("ss-fail");
    }
}
