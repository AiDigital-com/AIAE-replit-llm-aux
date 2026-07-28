package PACKAGE_REPLACE_ME.cachemanagement.updater;

import PACKAGE_REPLACE_ME.cachemanagement.config.CacheManagementProperties;
import PACKAGE_REPLACE_ME.cachemanagement.event.CacheInvalidationEvent;
import PACKAGE_REPLACE_ME.cachemanagement.event.CacheInvalidationEventService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Unit tests for monotonic, retry-safe cache invalidation polling.
 */
@ExtendWith(MockitoExtension.class)
class ScheduledCacheUpdaterTest {

	@Mock
	private CacheInvalidationEventService eventService;

	@Mock
	private CacheUpdaterService cacheUpdaterService;

	@Test
	void shouldProcessOrderedEventsAndAdvanceCursorTest() {
		CacheManagementProperties properties = new CacheManagementProperties();
		when(eventService.updatesAfter(0L, properties.getBatchSize())).thenReturn(List.of(
				new CacheInvalidationEvent(10L, "example.Team", Instant.now()),
				new CacheInvalidationEvent(11L, "example.Role", Instant.now())));
		ScheduledCacheUpdater updater =
				new ScheduledCacheUpdater(eventService, cacheUpdaterService, properties);

		updater.pollAndEvict();

		InOrder order = inOrder(cacheUpdaterService);
		order.verify(cacheUpdaterService).clearCachesForClass("example.Team");
		order.verify(cacheUpdaterService).clearCachesForClass("example.Role");
		assertThat(updater.getLastProcessedSequence()).isEqualTo(11L);
	}

	@Test
	void shouldKeepCursorOnFailedEvictionForRetryTest() {
		CacheManagementProperties properties = new CacheManagementProperties();
		CacheInvalidationEvent event =
				new CacheInvalidationEvent(7L, "example.Team", Instant.now());
		when(eventService.updatesAfter(0L, properties.getBatchSize())).thenReturn(List.of(event));
		org.mockito.Mockito.doThrow(new IllegalStateException("cache unavailable"))
				.when(cacheUpdaterService).clearCachesForClass("example.Team");
		ScheduledCacheUpdater updater =
				new ScheduledCacheUpdater(eventService, cacheUpdaterService, properties);

		assertThatThrownBy(updater::pollAndEvict)
				.isInstanceOf(IllegalStateException.class)
				.hasMessageContaining("cache unavailable");
		assertThat(updater.getLastProcessedSequence()).isZero();
	}

	@Test
	void shouldRejectNonIncreasingSequenceTest() {
		CacheManagementProperties properties = new CacheManagementProperties();
		when(eventService.updatesAfter(0L, properties.getBatchSize())).thenReturn(List.of(
				new CacheInvalidationEvent(0L, "example.Team", Instant.now())));
		ScheduledCacheUpdater updater =
				new ScheduledCacheUpdater(eventService, cacheUpdaterService, properties);

		assertThatThrownBy(updater::pollAndEvict)
				.isInstanceOf(IllegalStateException.class)
				.hasMessageContaining("strictly increasing");
		verifyNoInteractions(cacheUpdaterService);
	}

	@Test
	void shouldDoNothingWhenNoEventsTest() {
		CacheManagementProperties properties = new CacheManagementProperties();
		when(eventService.updatesAfter(0L, properties.getBatchSize())).thenReturn(List.of());
		ScheduledCacheUpdater updater =
				new ScheduledCacheUpdater(eventService, cacheUpdaterService, properties);

		updater.pollAndEvict();

		verifyNoInteractions(cacheUpdaterService);
		assertThat(updater.getLastProcessedSequence()).isZero();
	}
}
