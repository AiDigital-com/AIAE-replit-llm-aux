// PostgresUsageLogger — dispatches UsageEvent persistence to a separate
// Spring bean. The actual INSERT lives in UsageEventPersistenceService so
// @Transactional(REQUIRES_NEW) and @Async are applied through a proxy.

package PACKAGE_REPLACE_ME.usagelogging.loggers.impl;

import PACKAGE_REPLACE_ME.usagelogging.loggers.UsageLogger;
import PACKAGE_REPLACE_ME.usagelogging.models.UsageEvent;
import PACKAGE_REPLACE_ME.usagelogging.sink.UsageEventSink;
import lombok.RequiredArgsConstructor;

/**
 * Dispatches usage events into the configured {@link UsageEventSink} chain.
 */
@RequiredArgsConstructor
public class PostgresUsageLogger implements UsageLogger {

    private final UsageEventSink usageEventSink;

    @Override
    public void record(UsageEvent event) {
        usageEventSink.record(event);
    }
}
