package PACKAGE_REPLACE_ME.cachemanagement.updater;

import PACKAGE_REPLACE_ME.cachemanagement.config.CacheManagementProperties;
import PACKAGE_REPLACE_ME.cachemanagement.event.CacheInvalidationEvent;
import PACKAGE_REPLACE_ME.cachemanagement.event.CacheInvalidationEventService;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Polls the shared invalidation log by monotonic database event ID and clears
 * node-local cache regions. The cursor advances only after each event is
 * cleared successfully, so a failed clear is retried on the next poll.
 *
 * <p>The cursor is intentionally node-local. Hibernate/Ehcache regions are
 * heap-local and empty after a node restart, so replaying retained events from
 * sequence zero is safe and avoids timestamp/commit visibility races.
 */
@Component
@RequiredArgsConstructor
public class ScheduledCacheUpdater {

	private static final Logger LOG = LoggerFactory.getLogger(ScheduledCacheUpdater.class);

	private final CacheInvalidationEventService eventService;
	private final CacheUpdaterService cacheUpdaterService;
	private final CacheManagementProperties properties;

	private volatile long lastProcessedSequence;

	/**
	 * Processes bounded event pages. Additional work remains for the next fixed
	 * delay, preventing an old event backlog from monopolizing the scheduler.
	 */
	@Scheduled(
			fixedDelayString = "${app.cache-management.poll-interval-ms:15000}",
			initialDelayString = "${app.cache-management.initial-delay-ms:15000}")
	public void pollAndEvict() {
		for (int batch = 0; batch < properties.getMaxBatchesPerPoll(); batch++) {
			List<CacheInvalidationEvent> events =
					eventService.updatesAfter(lastProcessedSequence, properties.getBatchSize());
			if (events.isEmpty()) {
				return;
			}
			for (CacheInvalidationEvent event : events) {
				if (event.sequence() <= lastProcessedSequence) {
					throw new IllegalStateException(
							"Cache invalidation events must be ordered by strictly increasing sequence");
				}
				cacheUpdaterService.clearCachesForClass(event.trackedClass());
				lastProcessedSequence = event.sequence();
			}
			if (events.size() < properties.getBatchSize()) {
				return;
			}
		}
		LOG.warn(
				"Cache invalidation backlog remains after {} batches; cursor={}",
				properties.getMaxBatchesPerPoll(),
				lastProcessedSequence);
	}

	long getLastProcessedSequence() {
		return lastProcessedSequence;
	}
}
