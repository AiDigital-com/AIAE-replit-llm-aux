package PACKAGE_REPLACE_ME.cachemanagement.updater;

import PACKAGE_REPLACE_ME.cachemanagement.cache.CacheService;
import PACKAGE_REPLACE_ME.cachemanagement.registry.CacheNamesByClassService;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.Cache;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Default {@link CacheUpdaterService}: resolves region names from the registry and clears each region
 * found across the cache managers.
 */
@Service
@RequiredArgsConstructor
public class CacheUpdaterServiceImpl implements CacheUpdaterService {

	private static final Logger LOG = LoggerFactory.getLogger(CacheUpdaterServiceImpl.class);

	private final CacheService cacheService;
	private final CacheNamesByClassService cacheNamesByClassService;

	@Override
	public void clearCachesForClass(String className) {
		List<String> cacheNames = cacheNamesByClassService.getCacheNamesByClassName(className);
		if (cacheNames.isEmpty()) {
			throw new IllegalStateException(
					"No cache regions are registered for invalidation source " + className);
		}
		cacheNames.forEach(this::clearCache);
		LOG.debug("Cleared {} cache region(s) for class {}", cacheNames.size(), className);
	}

	@Override
	public void clearCache(String cacheName) {
		List<Cache> caches = cacheService.getCachesByName(cacheName);
		if (caches.isEmpty()) {
			throw new IllegalStateException(
					"Cache region '" + cacheName
							+ "' is registered for invalidation but not found in any cache manager");
		}
		caches.forEach(Cache::clear);
	}
}
