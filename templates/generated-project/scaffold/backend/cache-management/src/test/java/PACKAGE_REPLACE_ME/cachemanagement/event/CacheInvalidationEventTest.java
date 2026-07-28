package PACKAGE_REPLACE_ME.cachemanagement.event;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit test for the {@link CacheInvalidationEvent} record (accessors + value semantics).
 */
class CacheInvalidationEventTest {

	@Test
	void shouldExposeComponentsAndValueSemanticsTest() {
		// Given:
			Instant when = Instant.now();
			CacheInvalidationEvent event = new CacheInvalidationEvent(42L, "example.Foo", when);
			CacheInvalidationEvent same = new CacheInvalidationEvent(42L, "example.Foo", when);

		// Then:
			assertThat(event.sequence()).isEqualTo(42L);
			assertThat(event.trackedClass()).isEqualTo("example.Foo");
			assertThat(event.createdAt()).isEqualTo(when);
			assertThat(event).isEqualTo(same).hasSameHashCodeAs(same);
			assertThat(event.toString()).contains("example.Foo");
	}
}
