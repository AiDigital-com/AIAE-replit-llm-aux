package PACKAGE_REPLACE_ME.error.mapper;

import PACKAGE_REPLACE_ME.api.v1.model.AppApiExceptionResponseV1;
import PACKAGE_REPLACE_ME.api.v1.model.AppValidationExceptionResponseV1;
import PACKAGE_REPLACE_ME.api.v1.model.FieldToErrorResponseV1;
import PACKAGE_REPLACE_ME.service.common.error.CodeAwareThrowable;
import PACKAGE_REPLACE_ME.service.common.error.ErrorReason;
import PACKAGE_REPLACE_ME.service.common.time.CurrentTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.validation.FieldError;

/**
 * Default {@link GlobalExceptionResponseHelper} implementation.
 */
@Component
@RequiredArgsConstructor
public class GlobalExceptionResponseHelperImpl implements GlobalExceptionResponseHelper {

    private static final String MDC_CORRELATION_ID = "correlationId";
    private static final String DEFAULT_CORRELATION_ID = "n/a";

    private final CurrentTime currentTime;

    /**
     * Builds a single-error API response entity.
     *
     * @param exception exception carrying the response code and message
     * @param status    HTTP status to return
     * @return API exception response entity
     */
    @Override
    public ResponseEntity<AppApiExceptionResponseV1> buildApiError(Exception exception, HttpStatus status) {
        AppApiExceptionResponseV1 response = new AppApiExceptionResponseV1();
        if (exception instanceof CodeAwareThrowable codeAwareThrowable) {
            response.setCode(codeAwareThrowable.getCode());
        } else {
            response.setCode(ErrorReason.C000.getCode());
        }
        response.setMessage(exception.getMessage());
        response.setTimestamp(currentTime.nowLocalDateTime());
        response.setCorrelationId(currentCorrelationId());
        return new ResponseEntity<>(response, HttpStatusCode.valueOf(status.value()));
    }

    /**
     * Builds a validation envelope from Spring field errors.
     *
     * @param errors binding field errors
     * @return validation response body
     */
    @Override
    public AppValidationExceptionResponseV1 buildValidationErrorMessage(List<FieldError> errors) {
        List<FieldToErrorResponseV1> validationErrors = errors.stream()
            .map(this::buildFieldError)
            .toList();
        return validationResponse(validationErrors);
    }

    /**
     * Builds a validation envelope for a single field-level error.
     *
     * @param field invalid field name
     * @param error validation message
     * @return validation response body
     */
    @Override
    public AppValidationExceptionResponseV1 buildValidationErrorMessage(String field, String error) {
        return validationResponse(List.of(buildFieldError(field, error, null)));
    }

    /**
     * Maps a Spring {@link FieldError} to the generated OpenAPI field-error DTO.
     *
     * @param error Spring field error
     * @return generated field-error DTO
     */
    @Override
    public FieldToErrorResponseV1 buildFieldError(FieldError error) {
        return buildFieldError(error.getField(), error.getDefaultMessage(), error.getCode());
    }

    /**
     * Maps a field, message and optional validator code to the generated OpenAPI DTO.
     *
     * @param field invalid field name
     * @param error validation message
     * @param code  Spring validator code, or {@code null} for the default application code
     * @return generated field-error DTO
     */
    @Override
    public FieldToErrorResponseV1 buildFieldError(String field, String error, String code) {
        FieldToErrorResponseV1 response = new FieldToErrorResponseV1();
        response.setCode(code == null ? ErrorReason.C002.getCode() : code);
        response.setField(field);
        response.setError(error == null ? ErrorReason.C002.getDescription() : error);
        return response;
    }

    /**
     * Builds the validation response body from already mapped field errors.
     *
     * @param errors mapped validation field errors
     * @return validation response body
     */
    AppValidationExceptionResponseV1 validationResponse(List<FieldToErrorResponseV1> errors) {
        AppValidationExceptionResponseV1 response = new AppValidationExceptionResponseV1();
        response.setTimestamp(currentTime.nowLocalDateTime());
        response.setCorrelationId(currentCorrelationId());
        response.setErrors(errors);
        return response;
    }

    /**
     * Returns the current correlation id from the MDC, or a default placeholder.
     *
     * @return correlation id for error responses
     */
    String currentCorrelationId() {
        String correlationId = MDC.get(MDC_CORRELATION_ID);
        return correlationId == null || correlationId.isBlank() ? DEFAULT_CORRELATION_ID : correlationId;
    }
}
