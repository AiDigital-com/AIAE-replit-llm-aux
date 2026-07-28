package PACKAGE_REPLACE_ME.error.mapper;

import PACKAGE_REPLACE_ME.api.v1.model.AppApiExceptionResponseV1;
import PACKAGE_REPLACE_ME.api.v1.model.AppValidationExceptionResponseV1;
import PACKAGE_REPLACE_ME.api.v1.model.FieldToErrorResponseV1;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;

/**
 * Builds OpenAPI error response DTOs for the global exception handler.
 */
public interface GlobalExceptionResponseHelper {

    /**
     * Builds a single-error API response entity.
     *
     * @param exception exception carrying the response code and message
     * @param status    HTTP status to return
     * @return API exception response entity
     */
    ResponseEntity<AppApiExceptionResponseV1> buildApiError(Exception exception, HttpStatus status);

    /**
     * Builds a validation envelope from Spring field errors.
     *
     * @param errors binding field errors
     * @return validation response body
     */
    AppValidationExceptionResponseV1 buildValidationErrorMessage(List<FieldError> errors);

    /**
     * Builds a validation envelope for a single field-level error.
     *
     * @param field invalid field name
     * @param error validation message
     * @return validation response body
     */
    AppValidationExceptionResponseV1 buildValidationErrorMessage(String field, String error);

    /**
     * Maps a Spring {@link FieldError} to the generated OpenAPI field-error DTO.
     *
     * @param error Spring field error
     * @return generated field-error DTO
     */
    FieldToErrorResponseV1 buildFieldError(FieldError error);

    /**
     * Maps a field, message and optional validator code to the generated OpenAPI DTO.
     *
     * @param field invalid field name
     * @param error validation message
     * @param code  Spring validator code, or {@code null} for the default application code
     * @return generated field-error DTO
     */
    FieldToErrorResponseV1 buildFieldError(String field, String error, String code);
}
