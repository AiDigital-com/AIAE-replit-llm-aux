package PACKAGE_REPLACE_ME.external.googleworkspace;

import PACKAGE_REPLACE_ME.external.googleworkspace.config.GoogleWorkspaceProperties;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for {@link GoogleWorkspaceProperties} default values and compound helpers.
 */
class GoogleWorkspacePropertiesTest {

    @Test
    void shouldHaveAllServicesDisabledByDefaultTest() {
        // Given / When:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();

        // Then:
        assertThat(props.isDocsEnabled()).isFalse();
        assertThat(props.isDriveEnabled()).isFalse();
        assertThat(props.isSheetsEnabled()).isFalse();
        assertThat(props.isSlidesEnabled()).isFalse();
        assertThat(props.isStubEnabled()).isFalse();
        assertThat(props.getCredentialsJson()).isEmpty();
    }

    @Test
    void shouldReturnFalseWhenNoServicesEnabledTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();

        // When / Then:
        assertThat(props.isAnyProductionEnabled()).isFalse();
    }

    @Test
    void shouldReturnTrueWhenDocsEnabledTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();

        // When:
        props.setDocsEnabled(true);

        // Then:
        assertThat(props.isAnyProductionEnabled()).isTrue();
    }

    @Test
    void shouldReturnTrueWhenDriveEnabledTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();

        // When:
        props.setDriveEnabled(true);

        // Then:
        assertThat(props.isAnyProductionEnabled()).isTrue();
    }

    @Test
    void shouldReturnTrueWhenSheetsEnabledTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();

        // When:
        props.setSheetsEnabled(true);

        // Then:
        assertThat(props.isAnyProductionEnabled()).isTrue();
    }

    @Test
    void shouldReturnTrueWhenSlidesEnabledTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();

        // When:
        props.setSlidesEnabled(true);

        // Then:
        assertThat(props.isAnyProductionEnabled()).isTrue();
    }

    @Test
    void shouldStoreCredentialsJsonTest() {
        // Given:
        GoogleWorkspaceProperties props = new GoogleWorkspaceProperties();

        // When:
        props.setCredentialsJson("{\"type\":\"service_account\"}");

        // Then:
        assertThat(props.getCredentialsJson()).isEqualTo("{\"type\":\"service_account\"}");
    }
}
