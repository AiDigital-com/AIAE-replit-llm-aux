package PACKAGE_REPLACE_ME.service.cache;

import PACKAGE_REPLACE_ME.cachemanagement.config.CacheManagementProperties;
import PACKAGE_REPLACE_ME.cachemanagement.event.CacheInvalidationEvent;
import PACKAGE_REPLACE_ME.domain.cache.entities.CacheInvalidationEventEntity;
import PACKAGE_REPLACE_ME.domain.cache.repositories.CacheInvalidationEventRepository;
import PACKAGE_REPLACE_ME.service.common.time.CurrentTime;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageRequest;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Unit tests for the JPA cache-invalidation outbox adapter.
 */
@ExtendWith(MockitoExtension.class)
class JpaCacheInvalidationEventServiceTest {

	@Mock
	private CacheInvalidationEventRepository repository;

	@Mock
	private CurrentTime currentTime;

	@Test
	void shouldReadASequenceOrderedBoundedPageTest() {
		Instant createdAt = Instant.parse("2026-07-27T10:00:00Z");
		CacheInvalidationEventEntity entity =
				new CacheInvalidationEventEntity("example.Team", createdAt);
		entity.setId(12L);
		when(repository.findByIdGreaterThanOrderByIdAsc(10L, PageRequest.of(0, 100)))
				.thenReturn(List.of(entity));
		JpaCacheInvalidationEventService service = service();

		List<CacheInvalidationEvent> events = service.updatesAfter(10L, 100);

		assertThat(events).containsExactly(
				new CacheInvalidationEvent(12L, "example.Team", createdAt));
	}

	@Test
	void shouldPersistFullyQualifiedInvalidationSourceTest() {
		Instant now = Instant.parse("2026-07-27T10:00:00Z");
		when(currentTime.nowInstant()).thenReturn(now);
		JpaCacheInvalidationEventService service = service();

		service.publishUpdateEvent("example.Team");

		ArgumentCaptor<CacheInvalidationEventEntity> captor =
				ArgumentCaptor.forClass(CacheInvalidationEventEntity.class);
		verify(repository).save(captor.capture());
		assertThat(captor.getValue().getTrackedClass()).isEqualTo("example.Team");
		assertThat(captor.getValue().getCreatedAt()).isEqualTo(now);
	}

	@Test
	void shouldRejectInvalidArgumentsTest() {
		JpaCacheInvalidationEventService service = service();

		assertThatThrownBy(() -> service.updatesAfter(0L, 0))
				.isInstanceOf(IllegalArgumentException.class);
		assertThatThrownBy(() -> service.publishUpdateEvent(" "))
				.isInstanceOf(IllegalArgumentException.class);
	}

	@Test
	void shouldNotPruneEventsByDefaultTest() {
		JpaCacheInvalidationEventService service = service();

		service.cleanupOldEvents();

		verifyNoInteractions(repository, currentTime);
	}

	@Test
	void shouldPruneEventsOnlyWhenExplicitlyEnabledTest() {
		Instant now = Instant.parse("2026-07-27T10:00:00Z");
		when(currentTime.nowInstant()).thenReturn(now);
		CacheManagementProperties properties = new CacheManagementProperties();
		properties.setCleanupEnabled(true);
		JpaCacheInvalidationEventService service =
				new JpaCacheInvalidationEventService(repository, properties, currentTime);

		service.cleanupOldEvents();

		verify(repository).deleteCreatedBefore(now.minus(properties.getRetention()));
	}

	private JpaCacheInvalidationEventService service() {
		return new JpaCacheInvalidationEventService(
				repository,
				new CacheManagementProperties(),
				currentTime);
	}
}
