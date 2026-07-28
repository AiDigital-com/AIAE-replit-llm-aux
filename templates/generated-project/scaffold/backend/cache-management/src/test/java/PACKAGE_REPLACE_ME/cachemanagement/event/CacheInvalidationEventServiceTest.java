package PACKAGE_REPLACE_ME.cachemanagement.event;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit test for the {@link CacheInvalidationEventService} {@code Class} default overload.
 */
class CacheInvalidationEventServiceTest {

	@Test
	void shouldPublishUsingFullyQualifiedClassNameViaDefaultOverloadTest() {
		// Given: an implementation that records the published class name
		List<String> published = new ArrayList<>();
		CacheInvalidationEventService service = new CacheInvalidationEventService() {
			@Override
				public List<CacheInvalidationEvent> updatesAfter(long sequence, int limit) {
				return List.of();
			}

			@Override
			public void publishUpdateEvent(String trackedClass) {
				published.add(trackedClass);
			}
		};

		// When: the Class overload is used
		service.publishUpdateEvent(String.class);

		// Then: it delegates with the collision-safe fully qualified name
		assertThat(published).containsExactly("java.lang.String");
	}
}
