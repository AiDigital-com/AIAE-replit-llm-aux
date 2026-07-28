package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleWorkspaceExternalException;
import com.google.api.services.drive.Drive;
import com.google.api.services.drive.model.File;
import com.google.api.services.drive.model.FileList;
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
 * Unit tests for {@link GoogleDriveClientImpl} using a mock Drive service.
 */
@ExtendWith(MockitoExtension.class)
class GoogleDriveClientImplTest {

    @Mock
    private Drive driveService;

    @Test
    void shouldReturnFileIdsFromFolderTest() throws IOException {
        // Given:
        Drive.Files files = mock(Drive.Files.class);
        Drive.Files.List listRequest = mock(Drive.Files.List.class);

        File f1 = new File().setId("file-001");
        File f2 = new File().setId("file-002");
        FileList fileList = new FileList().setFiles(List.of(f1, f2));

        when(driveService.files()).thenReturn(files);
        when(files.list()).thenReturn(listRequest);
        when(listRequest.setQ(anyString())).thenReturn(listRequest);
        when(listRequest.setFields(anyString())).thenReturn(listRequest);
        when(listRequest.setPageSize(1000)).thenReturn(listRequest);
        when(listRequest.execute()).thenReturn(fileList);

        GoogleDriveClientImpl client = new GoogleDriveClientImpl(driveService);

        // When:
        List<String> result = client.listFiles("folder-xyz");

        // Then:
        assertThat(result).containsExactly("file-001", "file-002");
    }

    @Test
    void shouldReturnEmptyListWhenFolderHasNoFilesTest() throws IOException {
        // Given:
        Drive.Files files = mock(Drive.Files.class);
        Drive.Files.List listRequest = mock(Drive.Files.List.class);
        FileList fileList = new FileList().setFiles(null);

        when(driveService.files()).thenReturn(files);
        when(files.list()).thenReturn(listRequest);
        when(listRequest.setQ(anyString())).thenReturn(listRequest);
        when(listRequest.setFields(anyString())).thenReturn(listRequest);
        when(listRequest.setPageSize(1000)).thenReturn(listRequest);
        when(listRequest.execute()).thenReturn(fileList);

        GoogleDriveClientImpl client = new GoogleDriveClientImpl(driveService);

        // When:
        List<String> result = client.listFiles("empty-folder");

        // Then:
        assertThat(result).isEmpty();
    }

    @Test
    void shouldWrapIoExceptionInGoogleWorkspaceExternalExceptionTest() throws IOException {
        // Given:
        Drive.Files files = mock(Drive.Files.class);
        Drive.Files.List listRequest = mock(Drive.Files.List.class);

        when(driveService.files()).thenReturn(files);
        when(files.list()).thenReturn(listRequest);
        when(listRequest.setQ(anyString())).thenReturn(listRequest);
        when(listRequest.setFields(anyString())).thenReturn(listRequest);
        when(listRequest.setPageSize(1000)).thenReturn(listRequest);
        when(listRequest.execute()).thenThrow(new IOException("connection refused"));

        GoogleDriveClientImpl client = new GoogleDriveClientImpl(driveService);

        // When / Then:
        assertThatThrownBy(() -> client.listFiles("folder-fail"))
                .isInstanceOf(GoogleWorkspaceExternalException.class)
                .hasMessageContaining("folder-fail");
    }
}
