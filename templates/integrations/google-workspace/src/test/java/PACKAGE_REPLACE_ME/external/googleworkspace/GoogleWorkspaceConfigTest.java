package PACKAGE_REPLACE_ME.external.googleworkspace;

import PACKAGE_REPLACE_ME.external.googleworkspace.config.GoogleWorkspaceConfig;
import PACKAGE_REPLACE_ME.external.googleworkspace.config.GoogleWorkspaceProperties;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleDocsStubClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleDriveStubClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleSheetsStubClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleSlidesStubClient;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Tests for {@link GoogleWorkspaceConfig} bean selection and fail-fast behaviour.
 */
class GoogleWorkspaceConfigTest {

    private final GoogleWorkspaceConfig config = new GoogleWorkspaceConfig();

    @Test
    void shouldReturnNullClientsWhenNothingEnabledTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();

        // When / Then:
        assertThat(config.googleDocsClient(props)).isNull();
        assertThat(config.googleDriveClient(props)).isNull();
        assertThat(config.googleSheetsClient(props)).isNull();
        assertThat(config.googleSlidesClient(props)).isNull();
    }

    @Test
    void shouldReturnAllStubClientsWhenStubEnabledTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();
        props.setStubEnabled(true);

        // When / Then:
        assertThat(config.googleDocsClient(props)).isInstanceOf(GoogleDocsStubClient.class);
        assertThat(config.googleDriveClient(props)).isInstanceOf(GoogleDriveStubClient.class);
        assertThat(config.googleSheetsClient(props)).isInstanceOf(GoogleSheetsStubClient.class);
        assertThat(config.googleSlidesClient(props)).isInstanceOf(GoogleSlidesStubClient.class);
    }

    @Test
    void shouldFailFastWhenDocsEnabledWithoutCredentialsTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();
        props.setDocsEnabled(true);
        props.setCredentialsJson("");

        // When / Then:
        assertThatThrownBy(() -> config.googleDocsClient(props))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("credentials-json");
    }

    @Test
    void shouldFailFastWhenDriveEnabledWithoutCredentialsTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();
        props.setDriveEnabled(true);
        props.setCredentialsJson("");

        // When / Then:
        assertThatThrownBy(() -> config.googleDriveClient(props))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("credentials-json");
    }

    @Test
    void shouldFailFastWhenSheetsEnabledWithoutCredentialsTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();
        props.setSheetsEnabled(true);
        props.setCredentialsJson("");

        // When / Then:
        assertThatThrownBy(() -> config.googleSheetsClient(props))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("credentials-json");
    }

    @Test
    void shouldFailFastWhenSlidesEnabledWithoutCredentialsTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();
        props.setSlidesEnabled(true);
        props.setCredentialsJson("");

        // When / Then:
        assertThatThrownBy(() -> config.googleSlidesClient(props))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("credentials-json");
    }

    @Test
    void shouldReturnStubDocumentContentTest() {
        // Given:
        GoogleDocsStubClient stub = new GoogleDocsStubClient();

        // When:
        String content = stub.getDocumentContent("doc123");

        // Then:
        assertThat(content).contains("[STUB]").contains("doc123");
    }

    @Test
    void shouldReturnStubFileListTest() {
        // Given:
        GoogleDriveStubClient stub = new GoogleDriveStubClient();

        // When / Then:
        assertThat(stub.listFiles("folder456")).isNotEmpty();
    }

    @Test
    void shouldReturnStubSheetGridTest() {
        // Given:
        GoogleSheetsStubClient stub = new GoogleSheetsStubClient();

        // When / Then:
        assertThat(stub.readSheet("sheet789", "A1:B2")).hasSize(2);
    }

    @Test
    void shouldReturnStubPresentationTitleTest() {
        // Given:
        GoogleSlidesStubClient stub = new GoogleSlidesStubClient();

        // When / Then:
        assertThat(stub.getPresentationTitle("pres001")).contains("[STUB]");
    }

    @Test
    void shouldNotLeakCredentialJsonInFailFastMessageTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();
        props.setDocsEnabled(true);
        props.setCredentialsJson("");

        // When / Then:
        try {
            config.googleDocsClient(props);
        } catch (IllegalStateException ex) {
            assertThat(ex.getMessage()).doesNotContain("gsa.json");
        }
    }

    @Test
    void shouldThrowGoogleWorkspaceExternalExceptionWhenCredentialsJsonInvalidTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();
        props.setDocsEnabled(true);
        props.setCredentialsJson("not-valid-json");

        // When / Then:
        assertThatThrownBy(() -> config.googleDocsClient(props))
                .isInstanceOf(GoogleWorkspaceExternalException.class)
                .hasMessageContaining("credentials");
    }
}
