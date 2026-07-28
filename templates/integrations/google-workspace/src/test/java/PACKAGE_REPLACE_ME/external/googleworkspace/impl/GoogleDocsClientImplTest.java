package PACKAGE_REPLACE_ME.external.googleworkspace.impl;

import PACKAGE_REPLACE_ME.external.googleworkspace.GoogleWorkspaceExternalException;
import com.google.api.services.docs.v1.Docs;
import com.google.api.services.docs.v1.model.Body;
import com.google.api.services.docs.v1.model.Document;
import com.google.api.services.docs.v1.model.Paragraph;
import com.google.api.services.docs.v1.model.ParagraphElement;
import com.google.api.services.docs.v1.model.StructuralElement;
import com.google.api.services.docs.v1.model.TextRun;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;

import java.io.IOException;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link GoogleDocsClientImpl}.
 *
 * <p>{@code getDocumentContent()} tests use a Mockito spy to stub
 * {@code extractText()} and verify API-interaction in isolation.
 * {@code extractText()} is covered separately so each concern has a
 * single reason to fail.
 */
@ExtendWith(MockitoExtension.class)
class GoogleDocsClientImplTest {

    @Mock
    private Docs docsService;

    private GoogleDocsClientImpl client;

    @BeforeEach
    void setUp() {
        client = new GoogleDocsClientImpl(docsService);
    }

    // ── getDocumentContent() — API wiring (extractText stubbed via spy) ────

    @Test
    void shouldCallDocumentsGetWithCorrectDocumentIdTest() throws IOException {
        // Given:
        Docs.Documents documents = mock(Docs.Documents.class);
        Docs.Documents.Get getRequest = mock(Docs.Documents.Get.class);
        Document document = new Document();
        when(docsService.documents()).thenReturn(documents);
        when(documents.get("doc-abc")).thenReturn(getRequest);
        when(getRequest.execute()).thenReturn(document);
        GoogleDocsClientImpl spy = Mockito.spy(client);
        doReturn("stubbed content").when(spy).extractText(any(Document.class));

        // When:
        String result = spy.getDocumentContent("doc-abc");

        // Then:
        assertThat(result).isEqualTo("stubbed content");
    }

    @Test
    void shouldWrapIoExceptionInGoogleWorkspaceExternalExceptionTest() throws IOException {
        // Given:
        Docs.Documents documents = mock(Docs.Documents.class);
        Docs.Documents.Get getRequest = mock(Docs.Documents.Get.class);
        when(docsService.documents()).thenReturn(documents);
        when(documents.get("doc-fail")).thenReturn(getRequest);
        when(getRequest.execute()).thenThrow(new IOException("network error"));

        // When / Then:
        assertThatThrownBy(() -> client.getDocumentContent("doc-fail"))
                .isInstanceOf(GoogleWorkspaceExternalException.class)
                .hasMessageContaining("doc-fail");
    }

    @Test
    void shouldThrowWhenCredentialsJsonInvalidTest() {
        // Given: invalid JSON

        // When / Then:
        assertThatThrownBy(() -> new GoogleDocsClientImpl("not-valid-json"))
                .isInstanceOf(GoogleWorkspaceExternalException.class)
                .hasMessageContaining("credentials");
    }

    // ── extractText() — covered in isolation ──────────────────────────────

    @Test
    void shouldExtractTextFromDocumentBodyTest() {
        // Given:
        TextRun textRun = new TextRun().setContent("Hello world");
        ParagraphElement pe = new ParagraphElement().setTextRun(textRun);
        Paragraph paragraph = new Paragraph().setElements(List.of(pe));
        StructuralElement se = new StructuralElement().setParagraph(paragraph);
        Body body = new Body().setContent(List.of(se));
        Document document = new Document().setBody(body);

        // When:
        String result = client.extractText(document);

        // Then:
        assertThat(result).isEqualTo("Hello world");
    }

    @Test
    void shouldConcatenateMultipleParagraphsTest() {
        // Given:
        TextRun run1 = new TextRun().setContent("First. ");
        TextRun run2 = new TextRun().setContent("Second.");
        ParagraphElement pe1 = new ParagraphElement().setTextRun(run1);
        ParagraphElement pe2 = new ParagraphElement().setTextRun(run2);
        Paragraph p1 = new Paragraph().setElements(List.of(pe1));
        Paragraph p2 = new Paragraph().setElements(List.of(pe2));
        StructuralElement se1 = new StructuralElement().setParagraph(p1);
        StructuralElement se2 = new StructuralElement().setParagraph(p2);
        Body body = new Body().setContent(List.of(se1, se2));
        Document document = new Document().setBody(body);

        // When:
        String result = client.extractText(document);

        // Then:
        assertThat(result).isEqualTo("First. Second.");
    }

    @Test
    void shouldReturnEmptyStringWhenDocumentBodyIsNullTest() {
        // Given:
        Document document = new Document();

        // When:
        String result = client.extractText(document);

        // Then:
        assertThat(result).isEmpty();
    }

    @Test
    void shouldSkipNonParagraphStructuralElementsTest() {
        // Given:
        StructuralElement nonParagraph = new StructuralElement();
        TextRun run = new TextRun().setContent("text");
        ParagraphElement pe = new ParagraphElement().setTextRun(run);
        Paragraph para = new Paragraph().setElements(List.of(pe));
        StructuralElement withParagraph = new StructuralElement().setParagraph(para);
        Body body = new Body().setContent(List.of(nonParagraph, withParagraph));
        Document document = new Document().setBody(body);

        // When:
        String result = client.extractText(document);

        // Then:
        assertThat(result).isEqualTo("text");
    }
}
