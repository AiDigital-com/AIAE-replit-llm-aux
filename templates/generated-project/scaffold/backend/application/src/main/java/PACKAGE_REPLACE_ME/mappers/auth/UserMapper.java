package PACKAGE_REPLACE_ME.mappers.auth;

import PACKAGE_REPLACE_ME.api.v1.model.UserV1;
import PACKAGE_REPLACE_ME.config.ApplicationMapperConfig;
import PACKAGE_REPLACE_ME.service.common.security.AppUser;
import org.mapstruct.Mapper;

/**
 * Maps the service-layer {@link AppUser} to the API {@link UserV1} payload so
 * the controller stays thin and free of manual DTO assembly.
 */
@Mapper(config = ApplicationMapperConfig.class)
public interface UserMapper {

    /**
     * Converts the caller context into the API user payload.
     *
     * @param appUser authenticated caller context
     * @return API user payload (identity only; no baseline roles)
     */
    UserV1 toUserV1(AppUser appUser);
}
