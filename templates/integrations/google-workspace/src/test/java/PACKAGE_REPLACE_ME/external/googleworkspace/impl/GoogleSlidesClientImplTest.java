package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleWorkspaceExternalException;
import com.google.api.services.slides.v1.Slides;
import com.google.api.services.slides.v1.model.Presentation;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link GoogleSlidesClientImpl} using a mock Slides service.
 */
@ExtendWith(MockitoExtension.class)
class GoogleSlidesClientImplTest {

    @Mock
    private Slides slidesService;

    @Test
    void shouldReturnPresentationTitleTest() throws IOException {
        // Given:
        Slides.Presentations presentations = mock(Slides.Presentations.class);
        Slides.Presentations.Get getRequest = mock(Slides.Presentations.Get.class);
        Presentation presentation = new Presentation().setTitle("My Deck");

        when(slidesService.presentations()).thenReturn(presentations);
        when(presentations.get("pres-001")).thenReturn(getRequest);
        when(getRequest.execute()).thenReturn(presentation);

        GoogleSlidesClientImpl client = new GoogleSlidesClientImpl(slidesService);

        // When:
        String title = client.getPresentationTitle("pres-001");

        // Then:
        assertThat(title).isEqualTo("My Deck");
    }

    @Test
    void shouldReturnEmptyStringWhenTitleIsNullTest() throws IOException {
        // Given:
        Slides.Presentations presentations = mock(Slides.Presentations.class);
        Slides.Presentations.Get getRequest = mock(Slides.Presentations.Get.class);
        Presentation presentation = new Presentation();

        when(slidesService.presentations()).thenReturn(presentations);
        when(presentations.get("pres-notitle")).thenReturn(getRequest);
        when(getRequest.execute()).thenReturn(presentation);

        GoogleSlidesClientImpl client = new GoogleSlidesClientImpl(slidesService);

        // When:
        String title = client.getPresentationTitle("pres-notitle");

        // Then:
        assertThat(title).isEmpty();
    }

    @Test
    void shouldWrapIoExceptionInGoogleWorkspaceExternalExceptionTest() throws IOException {
        // Given:
        Slides.Presentations presentations = mock(Slides.Presentations.class);
        Slides.Presentations.Get getRequest = mock(Slides.Presentations.Get.class);

        when(slidesService.presentations()).thenReturn(presentations);
        when(presentations.get("pres-fail")).thenReturn(getRequest);
        when(getRequest.execute()).thenThrow(new IOException("API error"));

        GoogleSlidesClientImpl client = new GoogleSlidesClientImpl(slidesService);

        // When / Then:
        assertThatThrownBy(() -> client.getPresentationTitle("pres-fail"))
                .isInstanceOf(GoogleWorkspaceExternalException.class)
                .hasMessageContaining("pres-fail");
    }
}
