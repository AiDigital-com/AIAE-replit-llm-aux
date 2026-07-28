package PACKAGE_REPLACE_ME.error;

import PACKAGE_REPLACE_ME.api.v1.model.AppApiExceptionResponseV1;
import PACKAGE_REPLACE_ME.api.v1.model.AppValidationExceptionResponseV1;
import PACKAGE_REPLACE_ME.error.mapper.GlobalExceptionResponseHelperImpl;
import PACKAGE_REPLACE_ME.service.common.error.AppException;
import PACKAGE_REPLACE_ME.service.common.error.ErrorReason;
import PACKAGE_REPLACE_ME.service.common.time.CurrentTime;
import jakarta.validation.ConstraintViolationException;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;

import static org.assertj.core.api.Assertions.assertThat;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler =
        new GlobalExceptionHandler(new GlobalExceptionResponseHelperImpl(new FixedCurrentTime()));

    private static final class FixedCurrentTime implements CurrentTime {
        @Override
        public Instant nowInstant() {
            return Instant.parse("2026-01-01T00:00:00Z");
        }

        @Override
        public ZoneOffset getDefaultTimeZone() {
            return ZoneOffset.UTC;
        }
    }

    @Test
    void shouldMapAppExceptionCodesToHttpStatusesTest() {
        // Given / When / Then: each ErrorReason prefix maps to its HTTP status
        assertThat(status(ErrorReason.C001)).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(status(ErrorReason.C004)).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(status(ErrorReason.C005)).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(status(ErrorReason.C006)).isEqualTo(HttpStatus.CONFLICT);
        assertThat(status(ErrorReason.C007)).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(status(ErrorReason.C000)).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(status(ErrorReason.C002)).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    private HttpStatus status(ErrorReason reason) {
        return (HttpStatus) handler.handleAppException(new AppException(reason, "x")).getStatusCode();
    }

    @Test
    void shouldPopulateApiErrorBodyTest() {
        // When:
        ResponseEntity<AppApiExceptionResponseV1> resp = handler.handleAppException(
            new AppException(ErrorReason.C001, 42L));

        // Then:
        AppApiExceptionResponseV1 body = resp.getBody();
        assertThat(body).isNotNull();
        assertThat(body.getCode()).isEqualTo("C001");
        assertThat(body.getMessage()).contains("Resource not found");
        assertThat(body.getTimestamp()).isNotNull();
        assertThat(body.getCorrelationId()).isNotBlank();
    }

    @Test
    void shouldMapConstraintViolationToBadRequestTest() {
        // When:
        ResponseEntity<AppValidationExceptionResponseV1> resp = handler.handleConstraintViolation(
            new ConstraintViolationException("bad", null));

        // Then:
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody().getErrors()).hasSize(1);
        assertThat(resp.getBody().getErrors().get(0).getCode()).isEqualTo("C002");
    }

    @Test
    void shouldMapAuthAndAccessDeniedTest() {
        // When / Then:
        assertThat(handler.handleAuth(new BadCredentialsException("nope")).getStatusCode())
            .isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(handler.handleAccessDenied(new AccessDeniedException("no")).getStatusCode())
            .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void shouldMapUnknownToInternalServerErrorTest() {
        // When:
        ResponseEntity<AppApiExceptionResponseV1> resp = handler.handleUnknown(new RuntimeException("boom"));

        // Then:
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(resp.getBody().getCode()).isEqualTo("C000");
    }
}
