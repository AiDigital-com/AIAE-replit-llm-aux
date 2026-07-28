// GlobalExceptionHandler — single source of HTTP error translation.
// Catches AppException + Spring validation/security exceptions and converts
// them to OpenAPI-generated error DTOs. Controllers catch nothing;
// services throw AppException with ErrorReason.
//
// All response-building helpers live in GlobalExceptionResponseHelper so this
// class stays free of private methods.

package PACKAGE_REPLACE_ME.error;

import PACKAGE_REPLACE_ME.api.v1.model.AppApiExceptionResponseV1;
import PACKAGE_REPLACE_ME.api.v1.model.AppValidationExceptionResponseV1;
import PACKAGE_REPLACE_ME.error.mapper.GlobalExceptionResponseHelper;
import PACKAGE_REPLACE_ME.service.common.error.AppException;
import PACKAGE_REPLACE_ME.service.common.error.ErrorReason;
import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.lang.NonNull;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * Converts service and framework exceptions into the committed OpenAPI error shape.
 */
@ControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    private static final String REQUEST_FIELD = "request";

    /** Error-code prefixes that map to specific HTTP statuses. */
    private static final String NOT_FOUND_PREFIX = "C001";
    private static final String FORBIDDEN_PREFIX = "C004";
    private static final String UNAUTH_PREFIX = "C005";
    private static final String CONFLICT_PREFIX = "C006";
    private static final String RATE_LIMIT_PREFIX = "C007";
    private static final String INTERNAL_PREFIX = "C000";

    private final GlobalExceptionResponseHelper responseHelper;

    /**
     * Creates the exception handler.
     *
     * @param responseHelper helper that builds generated OpenAPI response DTOs
     */
    public GlobalExceptionHandler(GlobalExceptionResponseHelper responseHelper) {
        this.responseHelper = responseHelper;
    }

    /**
     * Handles canonical application exceptions.
     *
     * @param ex application exception carrying an error code
     * @return API error response with mapped HTTP status
     */
    @ExceptionHandler(AppException.class)
    public ResponseEntity<AppApiExceptionResponseV1> handleAppException(AppException ex) {
        HttpStatus status = statusForCode(ex.getCode());
        if (status.is5xxServerError()) {
            LOG.error("AppException {}: {}", ex.getCode(), ex.getMessage(), ex);
        } else {
            LOG.warn("AppException {}: {}", ex.getCode(), ex.getMessage());
        }
        return responseHelper.buildApiError(ex, status);
    }

    /**
     * Handles bean-validation failures raised by Spring MVC request-body binding.
     *
     * @param ex      validation exception from Spring MVC
     * @param headers response headers passed by Spring MVC
     * @param status  response status passed by Spring MVC
     * @param request current web request
     * @return 400 validation error response
     */
    @Override
    public ResponseEntity<Object> handleMethodArgumentNotValid(
        MethodArgumentNotValidException ex,
        @NonNull HttpHeaders headers,
        @NonNull HttpStatusCode status,
        @NonNull WebRequest request
    ) {
        return new ResponseEntity<>(
            responseHelper.buildValidationErrorMessage(ex.getBindingResult().getFieldErrors()),
            HttpStatus.BAD_REQUEST);
    }

    /**
     * Handles validation failures raised outside request-body binding.
     *
     * @param ex validation exception from Jakarta Validation
     * @return 400 validation error response
     */
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<AppValidationExceptionResponseV1> handleConstraintViolation(
        ConstraintViolationException ex
    ) {
        return new ResponseEntity<>(
            responseHelper.buildValidationErrorMessage(REQUEST_FIELD, ex.getMessage()),
            HttpStatus.BAD_REQUEST);
    }

    /**
     * Handles authentication failures.
     *
     * @param ex Spring Security authentication exception
     * @return 401 API error response
     */
    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<AppApiExceptionResponseV1> handleAuth(AuthenticationException ex) {
        return responseHelper.buildApiError(new AppException(ErrorReason.C005), HttpStatus.UNAUTHORIZED);
    }

    /**
     * Handles authenticated callers without sufficient permissions.
     *
     * @param ex Spring Security authorization exception
     * @return 403 API error response
     */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<AppApiExceptionResponseV1> handleAccessDenied(AccessDeniedException ex) {
        return responseHelper.buildApiError(
            new AppException(ErrorReason.C004, "detail", ex.getMessage()),
            HttpStatus.FORBIDDEN);
    }

    /**
     * Handles unexpected exceptions as opaque internal errors.
     *
     * @param ex unhandled exception
     * @return 500 API error response
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<AppApiExceptionResponseV1> handleUnknown(Exception ex) {
        LOG.error("Unhandled exception", ex);
        return responseHelper.buildApiError(
            new AppException(ErrorReason.C000, "class", ex.getClass().getSimpleName()),
            HttpStatus.INTERNAL_SERVER_ERROR);
    }

    /**
     * Maps an error code prefix to the corresponding HTTP status.
     *
     * @param code application error code
     * @return matching HTTP status
     */
    public HttpStatus statusForCode(String code) {
        if (code == null) {
            return HttpStatus.INTERNAL_SERVER_ERROR;
        }
        if (code.startsWith(NOT_FOUND_PREFIX)) {
            return HttpStatus.NOT_FOUND;
        }
        if (code.startsWith(FORBIDDEN_PREFIX)) {
            return HttpStatus.FORBIDDEN;
        }
        if (code.startsWith(UNAUTH_PREFIX)) {
            return HttpStatus.UNAUTHORIZED;
        }
        if (code.startsWith(CONFLICT_PREFIX)) {
            return HttpStatus.CONFLICT;
        }
        if (code.startsWith(RATE_LIMIT_PREFIX)) {
            return HttpStatus.TOO_MANY_REQUESTS;
        }
        if (code.startsWith(INTERNAL_PREFIX)) {
            return HttpStatus.INTERNAL_SERVER_ERROR;
        }
        return HttpStatus.BAD_REQUEST;
    }
}
