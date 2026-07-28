// NoOpUsageLogger — silent sink wired when app.usage-logging.enabled=false.
// Keeps the @LogUsage call sites cheap (assemble + drop) when usage
// logging is intentionally disabled (tests, local dev without DB).

package PACKAGE_REPLACE_ME.usagelogging.loggers.impl;

import PACKAGE_REPLACE_ME.usagelogging.loggers.UsageLogger;
import PACKAGE_REPLACE_ME.usagelogging.models.UsageEvent;

/**
 * Drops usage events when usage logging is intentionally disabled.
 */
public class NoOpUsageLogger implements UsageLogger {

    @Override
    public void record(UsageEvent event) {
        // no-op
    }
}
