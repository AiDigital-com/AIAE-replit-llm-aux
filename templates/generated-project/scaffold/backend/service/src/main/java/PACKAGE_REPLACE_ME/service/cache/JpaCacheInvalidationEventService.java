package PACKAGE_REPLACE_ME.service.cache;

import PACKAGE_REPLACE_ME.cachemanagement.config.CacheManagementProperties;
import PACKAGE_REPLACE_ME.cachemanagement.event.CacheInvalidationEvent;
import PACKAGE_REPLACE_ME.cachemanagement.event.CacheInvalidationEventService;
import PACKAGE_REPLACE_ME.domain.cache.entities.CacheInvalidationEventEntity;
import PACKAGE_REPLACE_ME.domain.cache.repositories.CacheInvalidationEventRepository;
import PACKAGE_REPLACE_ME.service.common.time.CurrentTime;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

/**
 * JPA outbox implementation shared by every application node.
 *
 * <p>Publication requires an existing transaction so the data mutation and its
 * invalidation row commit or roll back atomically.
 */
@Service
@RequiredArgsConstructor
public class JpaCacheInvalidationEventService implements CacheInvalidationEventService {

	private static final Logger LOG =
			LoggerFactory.getLogger(JpaCacheInvalidationEventService.class);

	private final CacheInvalidationEventRepository repository;
	private final CacheManagementProperties properties;
	private final CurrentTime currentTime;

	@Override
	@Transactional(readOnly = true)
	public List<CacheInvalidationEvent> updatesAfter(long sequence, int limit) {
		if (limit < 1) {
			throw new IllegalArgumentException("limit must be positive");
		}
		return repository
				.findByIdGreaterThanOrderByIdAsc(sequence, PageRequest.of(0, limit))
				.stream()
				.map(entity -> new CacheInvalidationEvent(
						entity.getId(),
						entity.getTrackedClass(),
						entity.getCreatedAt()))
				.toList();
	}

	@Override
	@Transactional(propagation = Propagation.MANDATORY)
	public void publishUpdateEvent(String trackedClass) {
		if (trackedClass == null || trackedClass.isBlank()) {
			throw new IllegalArgumentException("trackedClass must not be blank");
		}
		CacheInvalidationEventEntity event =
				new CacheInvalidationEventEntity(trackedClass, currentTime.nowInstant());
		repository.save(event);
	}

	/**
	 * Prunes old events only when operators explicitly enable retention cleanup.
	 *
	 * <p>Cleanup is disabled by default because deleting an event that a live,
	 * temporarily disconnected node has not processed can leave that node's
	 * heap-local cache stale. Enable it only with an enforced maximum polling
	 * outage and a restart or full-cache-clear policy for nodes that exceed it.
	 */
	@Scheduled(cron = "${app.cache-management.cleanup-cron:0 30 1 * * *}")
	@Transactional
	public void cleanupOldEvents() {
		if (!properties.isCleanupEnabled()) {
			return;
		}
		Instant cutoff = currentTime.nowInstant().minus(properties.getRetention());
		int deleted = repository.deleteCreatedBefore(cutoff);
		if (deleted > 0) {
			LOG.info("Pruned {} cache invalidation event(s) older than {}", deleted, cutoff);
		}
	}
}
