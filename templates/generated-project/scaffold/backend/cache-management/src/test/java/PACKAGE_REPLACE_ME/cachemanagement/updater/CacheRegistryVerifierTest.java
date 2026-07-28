package PACKAGE_REPLACE_ME.cachemanagement.updater;

import PACKAGE_REPLACE_ME.cachemanagement.cache.CacheService;
import PACKAGE_REPLACE_ME.cachemanagement.config.CacheManagementProperties;
import PACKAGE_REPLACE_ME.cachemanagement.registry.CacheNamesByClassService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.cache.Cache;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link CacheRegistryVerifier}.
 */
@ExtendWith(MockitoExtension.class)
class CacheRegistryVerifierTest {

	@Mock
	private CacheService cacheService;

	@Mock
	private CacheNamesByClassService cacheNamesByClassService;

	private final CacheManagementProperties properties = new CacheManagementProperties();

	@Test
	void shouldDoNothingWhenDisabledTest() {
		// Given: verify-registry defaults to false

		// When / Then: no registry/cache lookups, no failure
		CacheRegistryVerifier verifier =
				new CacheRegistryVerifier(cacheService, cacheNamesByClassService, properties);
		assertThatCode(verifier::verify).doesNotThrowAnyException();
	}

	@Test
	void shouldThrowWhenRegisteredRegionIsMissingTest() {
		// Given:
		properties.setVerifyRegistry(true);
		when(cacheNamesByClassService.getAllCacheNames()).thenReturn(List.of("missing"));
		when(cacheService.getCachesByName("missing")).thenReturn(List.of());
		CacheRegistryVerifier verifier =
				new CacheRegistryVerifier(cacheService, cacheNamesByClassService, properties);

		// When / Then:
		assertThatThrownBy(verifier::verify)
				.isInstanceOf(IllegalStateException.class)
				.hasMessageContaining("missing");
	}

	@Test
	void shouldPassWhenEveryRegionExistsTest() {
		// Given:
		properties.setVerifyRegistry(true);
		when(cacheNamesByClassService.getAllCacheNames()).thenReturn(List.of("present"));
		when(cacheService.getCachesByName("present")).thenReturn(List.of(org.mockito.Mockito.mock(Cache.class)));
		CacheRegistryVerifier verifier =
				new CacheRegistryVerifier(cacheService, cacheNamesByClassService, properties);

		// When / Then:
		assertThatCode(verifier::verify).doesNotThrowAnyException();
	}
}
