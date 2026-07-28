package PACKAGE_REPLACE_ME.security;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Typed browser security configuration bound from {@code app.security.*}.
 */
@Getter
@Validated
@ConfigurationProperties(prefix = "app.security")
public class SecurityProperties {

    private final Cors cors = new Cors();
    private final Csp csp = new Csp();

    /**
     * Cross-origin resource sharing settings.
     */
    @Getter
    @Setter
    public static class Cors {
        @NotBlank
        private String allowedOrigins =
            "https://*.replit.dev,https://*.repl.co,http://localhost:5173,http://localhost:5000";

        private long maxAgeSeconds = 3600L;

    }

    /**
     * Content Security Policy settings.
     */
    @Getter
    @Setter
    public static class Csp {
        @NotBlank
        private String defaultSrc = "'self'";

        @NotBlank
        private String frameAncestors = "'self' https://*.replit.dev https://*.repl.co";

        @NotBlank
        private String scriptSrc =
            "'self' 'unsafe-inline' https://*.clerk.accounts.dev https://challenges.cloudflare.com";

        @NotBlank
        private String workerSrc = "'self' blob:";

        @NotBlank
        private String frameSrc =
            "'self' https://*.clerk.accounts.dev https://challenges.cloudflare.com "
            + "https://www.youtube.com https://www.youtube-nocookie.com";

        @NotBlank
        private String styleSrc = "'self' 'unsafe-inline'";

        @NotBlank
        private String imgSrc = "'self' data: https:";

        @NotBlank
        private String connectSrc = "'self' https:";

        @NotBlank
        private String fontSrc = "'self' data:";

    }
}
