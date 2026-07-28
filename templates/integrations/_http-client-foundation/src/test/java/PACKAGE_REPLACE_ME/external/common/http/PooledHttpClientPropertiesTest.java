package PACKAGE_REPLACE_ME.external.common.http;

import PACKAGE_REPLACE_ME.external.common.http.config.PooledHttpClientProperties;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit tests for {@link PooledHttpClientProperties} default values and
 * JSR-303 constraint enforcement.
 */
class PooledHttpClientPropertiesTest {

    private static Validator validator;

    @BeforeAll
    static void buildValidator() {
        try (ValidatorFactory factory = Validation.buildDefaultValidatorFactory()) {
            validator = factory.getValidator();
        }
    }

    @Test
    void shouldApplyDefaultValuesTest() {
        // Given / When:
        PooledHttpClientProperties props = new PooledHttpClientProperties();

        // Then:
        assertThat(props.getConnectTimeout()).isEqualTo(Duration.ofSeconds(5));
        assertThat(props.getResponseTimeout()).isEqualTo(Duration.ofSeconds(30));
        assertThat(props.getConnectionRequestTimeout()).isEqualTo(Duration.ofSeconds(5));
        assertThat(props.getMaxTotalConnections()).isEqualTo(50);
        assertThat(props.getMaxConnectionsPerRoute()).isEqualTo(10);
        assertThat(props.getKeepAliveDuration()).isEqualTo(Duration.ofSeconds(60));
        assertThat(props.getIdleEvictionDuration()).isEqualTo(Duration.ofSeconds(30));
    }

    @Test
    void shouldPassValidationWithDefaultValuesTest() {
        // Given:
        PooledHttpClientProperties props = new PooledHttpClientProperties();

        // When:
        Set<ConstraintViolation<PooledHttpClientProperties>> violations = validator.validate(props);

        // Then:
        assertThat(violations).isEmpty();
    }

    @Test
    void shouldApplyCustomValuesTest() {
        // Given:
        PooledHttpClientProperties props = new PooledHttpClientProperties();

        // When:
        props.setConnectTimeout(Duration.ofSeconds(10));
        props.setResponseTimeout(Duration.ofSeconds(60));
        props.setConnectionRequestTimeout(Duration.ofSeconds(8));
        props.setMaxTotalConnections(100);
        props.setMaxConnectionsPerRoute(20);
        props.setKeepAliveDuration(Duration.ofMinutes(2));
        props.setIdleEvictionDuration(Duration.ofMinutes(1));

        // Then:
        assertThat(props.getConnectTimeout()).isEqualTo(Duration.ofSeconds(10));
        assertThat(props.getResponseTimeout()).isEqualTo(Duration.ofSeconds(60));
        assertThat(props.getConnectionRequestTimeout()).isEqualTo(Duration.ofSeconds(8));
        assertThat(props.getMaxTotalConnections()).isEqualTo(100);
        assertThat(props.getMaxConnectionsPerRoute()).isEqualTo(20);
        assertThat(props.getKeepAliveDuration()).isEqualTo(Duration.ofMinutes(2));
        assertThat(props.getIdleEvictionDuration()).isEqualTo(Duration.ofMinutes(1));
    }

    @Test
    void shouldFailValidationWhenConnectTimeoutIsNullTest() {
        // Given:
        PooledHttpClientProperties props = new PooledHttpClientProperties();
        props.setConnectTimeout(null);

        // When:
        Set<ConstraintViolation<PooledHttpClientProperties>> violations = validator.validate(props);

        // Then:
        assertThat(violations).isNotEmpty();
        assertThat(violations).anyMatch(v -> v.getPropertyPath().toString().equals("connectTimeout"));
    }

    @Test
    void shouldFailValidationWhenResponseTimeoutIsNullTest() {
        // Given:
        PooledHttpClientProperties props = new PooledHttpClientProperties();
        props.setResponseTimeout(null);

        // When:
        Set<ConstraintViolation<PooledHttpClientProperties>> violations = validator.validate(props);

        // Then:
        assertThat(violations).isNotEmpty();
        assertThat(violations).anyMatch(v -> v.getPropertyPath().toString().equals("responseTimeout"));
    }

    @Test
    void shouldFailValidationWhenMaxTotalConnectionsIsZeroTest() {
        // Given:
        PooledHttpClientProperties props = new PooledHttpClientProperties();
        props.setMaxTotalConnections(0);

        // When:
        Set<ConstraintViolation<PooledHttpClientProperties>> violations = validator.validate(props);

        // Then:
        assertThat(violations).isNotEmpty();
        assertThat(violations).anyMatch(v -> v.getPropertyPath().toString().equals("maxTotalConnections"));
    }

    @Test
    void shouldFailValidationWhenMaxConnectionsPerRouteIsNegativeTest() {
        // Given:
        PooledHttpClientProperties props = new PooledHttpClientProperties();
        props.setMaxConnectionsPerRoute(-1);

        // When:
        Set<ConstraintViolation<PooledHttpClientProperties>> violations = validator.validate(props);

        // Then:
        assertThat(violations).isNotEmpty();
        assertThat(violations).anyMatch(v -> v.getPropertyPath().toString().equals("maxConnectionsPerRoute"));
    }
}
