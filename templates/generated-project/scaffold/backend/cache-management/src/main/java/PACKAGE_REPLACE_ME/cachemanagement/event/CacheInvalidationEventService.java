package PACKAGE_REPLACE_ME.cachemanagement.event;

import java.util.List;

/**
 * Stores and reads cross-node cache-invalidation events.
 *
 * <p>The application provides an implementation backed by shared storage (e.g. a database table) so
 * that an event published on one node is visible to every other node's poller. The publishing node
 * also re-reads its own events on the next poll, which keeps all nodes — including the writer —
 * consistent.
 */
public interface CacheInvalidationEventService {

	/**
	 * Returns a bounded page of invalidation events after a monotonic event ID.
	 *
	 * @param sequence exclusive lower event-ID bound
	 * @param limit maximum number of events to return
	 * @return matching events ordered by sequence ascending
	 */
	List<CacheInvalidationEvent> updatesAfter(long sequence, int limit);

	/**
	 * Publishes an invalidation event for the given simple class name.
	 *
     * @param trackedClass fully qualified name of the class that changed
	 */
	void publishUpdateEvent(String trackedClass);

	/**
	 * Publishes an invalidation event for the given class.
	 *
	 * @param trackedClass the class that changed
	 */
    default void publishUpdateEvent(Class<?> trackedClass) {
        publishUpdateEvent(trackedClass.getName());
    }
}
