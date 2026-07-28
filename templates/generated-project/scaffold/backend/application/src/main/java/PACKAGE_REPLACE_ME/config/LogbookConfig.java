// LogbookConfig — application-owned metadata-only HTTP logging with required masking.
// Canonical spec: .claude/agent_docs/observability/logbook-http-logging-rules.md.
// Binds app.logbook.* properties (see application.yml baseline). Logbook's
// permissive defaults are NOT enough — this config enforces the company
// rules (Authorization/JWT masked; secret-like JSON fields masked;
// health/spec/swagger/options excluded).

package PACKAGE_REPLACE_ME.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.zalando.logbook.BodyFilter;
import org.zalando.logbook.HeaderFilter;
import org.zalando.logbook.HttpRequest;
import org.zalando.logbook.Logbook;
import org.zalando.logbook.core.BodyFilters;
import org.zalando.logbook.core.Conditions;
import org.zalando.logbook.core.DefaultHttpLogWriter;
import org.zalando.logbook.core.DefaultSink;
import org.zalando.logbook.core.HeaderFilters;
import org.zalando.logbook.core.WithoutBodyStrategy;
import org.zalando.logbook.json.JsonBodyFilters;
import org.zalando.logbook.json.JsonHttpLogFormatter;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Predicate;

/**
 * Configures application HTTP logging and masking.
 */
@Configuration
@EnableConfigurationProperties(LogbookConfig.LogbookProperties.class)
public class LogbookConfig {

    /**
     * Builds the Logbook instance used by the servlet filter.
     *
     * @param props bound masking and exclusion settings
     * @return configured Logbook instance
     */
    @Bean
    Logbook logbook(LogbookProperties props) {
        HeaderFilter headerFilter = HeaderFilters.replaceHeaders(
            name -> props.getHeadersToCensor().stream()
                .anyMatch(h -> h.equalsIgnoreCase(name)),
            props.getCensoredReplacement()
        );

        List<BodyFilter> bodyFilters = new ArrayList<>();
        for (String pattern : props.getJsonFieldsToCensor()) {
            bodyFilters.add(JsonBodyFilters.replaceJsonStringProperty(
                Set.of(pattern), props.getCensoredReplacement()));
        }
        BodyFilter combinedBodyFilter = bodyFilters.stream()
            .reduce(BodyFilter::merge)
            .orElse(BodyFilters.defaultValue());

        // Exclude noisy infrastructure (actuator, swagger, OpenAPI spec,
        // health probes, all OPTIONS). Each entry: path → list of methods.
        List<Predicate<HttpRequest>> exclusions = props.getExcluded().entrySet().stream()
            .flatMap(e -> e.getValue().stream()
                .map(method -> {
                    Predicate<HttpRequest> pathMatches = Conditions.requestTo(e.getKey());
                    Predicate<HttpRequest> methodMatches = Conditions.requestWithMethod(method);
                    return pathMatches.and(methodMatches);
                }))
            .toList();

        return Logbook.builder()
            .condition(Conditions.exclude(exclusions))
            .headerFilter(headerFilter)
            .bodyFilter(combinedBodyFilter)
            .strategy(new WithoutBodyStrategy())
            .sink(new DefaultSink(new JsonHttpLogFormatter(), new DefaultHttpLogWriter()))
            .build();
    }

    /**
     * Binds `app.logbook.*` from application.yml. Defaults mirror the
     * canonical rules so a fresh project is compliant without overrides.
     */
    @ConfigurationProperties("app.logbook")
    @Getter
    @Setter
    public static class LogbookProperties {
        private String censoredReplacement = "XXX";
        private List<String> headersToCensor = List.of(
            "Authorization", "Cookie", "Set-Cookie",
            "X-API-Key", "AccessKey", "Proxy-Authorization");
        private List<String> jsonFieldsToCensor = List.of(
            ".*password.*", ".*token.*", ".*secret.*", ".*key.*",
            ".*credential.*", ".*authorization.*",
            "privateKey", "clientSecret", "serviceAccount");
        private Map<String, List<String>> excluded = Map.of(
            "/**/actuator/**", List.of("GET"),
            "/**/swagger-ui/**", List.of("GET"),
            "/**/specs/**", List.of("GET"),
            "/health", List.of("GET"),
            "/**", List.of("OPTIONS"));

    }
}
