package PACKAGE_REPLACE_ME.external.googleworkspace.config;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleDocsClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleDriveClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleSheetsClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleSlidesClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleDocsClientImpl;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleDocsStubClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleDriveClientImpl;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleDriveStubClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleSheetsClientImpl;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleSheetsStubClient;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleSlidesClientImpl;
import PACKAGE_REPLACE_ME.external.googleworkspace.impl.GoogleSlidesStubClient;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Conditionally creates Google Workspace API beans based on properties.
 */
@Configuration
@EnableConfigurationProperties(GoogleWorkspaceProperties.class)
public class GoogleWorkspaceConfig {

    /**
     * Creates the Google Docs client when Docs or stub mode is enabled.
     *
     * @param properties Google Workspace adapter properties
     * @return Docs client, or {@code null} when disabled in direct unit calls
     */
    @Bean
    @ConditionalOnExpression(
        "${app.external.google-workspace.docs-enabled:false} || ${app.external.google-workspace.stub-enabled:false}")
    public GoogleDocsClient googleDocsClient(GoogleWorkspaceProperties properties) {
        if (properties.isStubEnabled()) {
            return new GoogleDocsStubClient();
        }
        if (!properties.isDocsEnabled()) {
            return null;
        }
        assertCredentialsPresent(properties, "docs-enabled");
        return new GoogleDocsClientImpl(properties.getCredentialsJson());
    }

    /**
     * Creates the Google Drive client when Drive or stub mode is enabled.
     *
     * @param properties Google Workspace adapter properties
     * @return Drive client, or {@code null} when disabled in direct unit calls
     */
    @Bean
    @ConditionalOnExpression(
        "${app.external.google-workspace.drive-enabled:false} || ${app.external.google-workspace.stub-enabled:false}")
    public GoogleDriveClient googleDriveClient(GoogleWorkspaceProperties properties) {
        if (properties.isStubEnabled()) {
            return new GoogleDriveStubClient();
        }
        if (!properties.isDriveEnabled()) {
            return null;
        }
        assertCredentialsPresent(properties, "drive-enabled");
        return new GoogleDriveClientImpl(properties.getCredentialsJson());
    }

    /**
     * Creates the Google Sheets client when Sheets or stub mode is enabled.
     *
     * @param properties Google Workspace adapter properties
     * @return Sheets client, or {@code null} when disabled in direct unit calls
     */
    @Bean
    @ConditionalOnExpression(
        "${app.external.google-workspace.sheets-enabled:false} || ${app.external.google-workspace.stub-enabled:false}")
    public GoogleSheetsClient googleSheetsClient(GoogleWorkspaceProperties properties) {
        if (properties.isStubEnabled()) {
            return new GoogleSheetsStubClient();
        }
        if (!properties.isSheetsEnabled()) {
            return null;
        }
        assertCredentialsPresent(properties, "sheets-enabled");
        return new GoogleSheetsClientImpl(properties.getCredentialsJson());
    }

    /**
     * Creates the Google Slides client when Slides or stub mode is enabled.
     *
     * @param properties Google Workspace adapter properties
     * @return Slides client, or {@code null} when disabled in direct unit calls
     */
    @Bean
    @ConditionalOnExpression(
        "${app.external.google-workspace.slides-enabled:false} || ${app.external.google-workspace.stub-enabled:false}")
    public GoogleSlidesClient googleSlidesClient(GoogleWorkspaceProperties properties) {
        if (properties.isStubEnabled()) {
            return new GoogleSlidesStubClient();
        }
        if (!properties.isSlidesEnabled()) {
            return null;
        }
        assertCredentialsPresent(properties, "slides-enabled");
        return new GoogleSlidesClientImpl(properties.getCredentialsJson());
    }

    /**
     * Fails fast when production Google Workspace adapters are enabled without credentials.
     *
     * @param props       Google Workspace adapter properties
     * @param enabledFlag property flag that triggered production client creation
     */
    private void assertCredentialsPresent(GoogleWorkspaceProperties props, String enabledFlag) {
        if (props.getCredentialsJson() == null || props.getCredentialsJson().isBlank()) {
            throw new IllegalStateException(
                "app.external.google-workspace.credentials-json must be set when "
                    + enabledFlag + " is true. "
                    + "Set GOOGLE_WORKSPACE_CREDENTIALS_JSON to the service-account JSON string.");
        }
    }
}
