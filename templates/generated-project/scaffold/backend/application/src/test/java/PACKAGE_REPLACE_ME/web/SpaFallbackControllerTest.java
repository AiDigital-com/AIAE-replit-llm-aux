package PACKAGE_REPLACE_ME.web;

import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class SpaFallbackControllerTest {

    @Test
    void shouldServeSpaForRootTest() throws Exception {
        // Given:
        MockMvc mvc = MockMvcBuilders.standaloneSetup(new SpaFallbackController()).build();

        // When:
        ResultActions response = mvc.perform(get("/"));

        // Then:
        response.andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/html"));
    }

    @Test
    void shouldServeSpaForSingleSegmentRouteTest() throws Exception {
        // Given:
        MockMvc mvc = MockMvcBuilders.standaloneSetup(new SpaFallbackController()).build();

        // When:
        ResultActions response = mvc.perform(get("/reports"));

        // Then:
        response.andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/html"));
    }

    @Test
    void shouldServeSpaForNestedRouteTest() throws Exception {
        // Given:
        MockMvc mvc = MockMvcBuilders.standaloneSetup(new SpaFallbackController()).build();

        // When:
        ResultActions response = mvc.perform(get("/reports/123/edit"));

        // Then:
        response.andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/html"));
    }

    @Test
    void shouldNotClaimApiRoutesTest() throws Exception {
        // Given:
        MockMvc mvc = MockMvcBuilders.standaloneSetup(new SpaFallbackController()).build();

        // When:
        ResultActions response = mvc.perform(get("/api/v1/resources"));

        // Then:
        response.andExpect(status().isNotFound());
    }
}
