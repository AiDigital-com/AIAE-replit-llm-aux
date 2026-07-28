// @ConfigurationProperties bean — typed home for Clerk SSO settings.
// Maps from application.yml `app.auth.*` and the AUTH_* / CLERK_* env vars.

package PACKAGE_REPLACE_ME.security;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Typed configuration for Clerk SSO authentication.
 */
@Getter
@Setter
@Validated
@ConfigurationProperties(prefix = "app.auth")
public class AuthProperties {

    /** Company email domain without a leading {@code @}. */
    private String allowedEmailDomain = "aidigital.com";

    /** Clerk publishable key — derives issuer/JWKS when explicit URIs are blank. */
    private String publishableKey;

    /**
     * Comma-separated list of exact trusted browser origins for the JWT
     * {@code azp} (authorized party) claim, e.g.
     * {@code http://localhost:5173,https://my-app.replit.app}. Never a Clerk
     * publishable key. Blank fails startup via {@link AuthStartupValidator}.
     */
    private String authorizedParties = "";

    @NotNull
    private Sso sso = new Sso();

    /**
     * SSO/OIDC settings for Clerk or another compatible provider.
     */
    @Getter
    @Setter
    public static class Sso {
        /** Clerk issuer URI, e.g. https://clean-clerk.clerk.accounts.dev */
        private String issuerUri;
        /** Optional JWKS override; usually discovered from issuerUri. */
        private String jwkSetUri;
        /** Expected `aud` claim value. */
        private String audience;
    }
}
