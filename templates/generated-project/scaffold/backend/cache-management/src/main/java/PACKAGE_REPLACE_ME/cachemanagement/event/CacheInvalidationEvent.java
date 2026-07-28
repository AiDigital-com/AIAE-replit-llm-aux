package PACKAGE_REPLACE_ME.cachemanagement.event;

import java.time.Instant;

/**
 * A cross-node cache-invalidation event from the shared append-only event log.
 *
 * @param sequence monotonically increasing database event ID
 * @param trackedClass fully qualified name of the class that changed
 * @param createdAt when the event was persisted
 */
public record CacheInvalidationEvent(long sequence, String trackedClass, Instant createdAt) {
}
