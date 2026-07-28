// @ConfigurationProperties bean — typed home for L2 cache warm-up settings.
// Maps from application.yml `app.cache.*` and the APP_CACHE_* env vars.

package PACKAGE_REPLACE_ME.cache;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Typed configuration for L2 cache warm-up.
 */
@Getter
@Setter
@Validated
@ConfigurationProperties(prefix = "app.cache")
public class CacheProperties {

    /** Whether to warm up {@link PACKAGE_REPLACE_ME.domain.ToWarmUp} repositories on startup. */
    private boolean warmupEnabled = false;
}
