package PACKAGE_REPLACE_ME.migrations;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Smoke-checks that {@code db.changelog-master.xml} applies cleanly against
 * a real Postgres (Testcontainers). Catches Liquibase XML syntax errors,
 * tier-mismatched constraints, and missing column types BEFORE the migration
 * runs in Replit deployment.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
class LiquibaseChangelogSmokeTest {

    @Container
    @ServiceConnection
    private static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16-alpine");

    @Test
    void shouldApplyMasterChangelogToPostgresTest() {
    }
}
