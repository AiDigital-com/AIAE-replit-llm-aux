package PACKAGE_REPLACE_ME.service.cache;

import PACKAGE_REPLACE_ME.cachemanagement.registry.CacheNamesByClassRegistry;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

/**
 * Application-owned mapping from mutation sources to every affected Hibernate
 * L2, query-cache, and Spring cache region.
 *
 * <p>The scaffold starts empty because it contains no production cached
 * entities. Add an entry whenever caching is introduced; region names must
 * match {@code ehcache.xml} exactly.
 */
@Component
public class ApplicationCacheNamesByClassRegistry implements CacheNamesByClassRegistry {

	@Override
	public Map<Class<?>, List<String>> cacheNamesByClassMap() {
		return Map.of();
	}
}
