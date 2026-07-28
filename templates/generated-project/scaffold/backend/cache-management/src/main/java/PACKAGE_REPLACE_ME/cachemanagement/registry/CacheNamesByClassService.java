package PACKAGE_REPLACE_ME.cachemanagement.registry;

import java.util.List;

/**
 * Resolves cache region names from the {@link CacheNamesByClassRegistry} by
 * fully qualified class name, the collision-safe identity carried by events.
 */
public interface CacheNamesByClassService {

	/**
	 * Returns the cache region names registered for the given simple class name.
	 *
     * @param className fully qualified class name
	 * @return the registered cache names, or an empty list when none are registered
	 */
    List<String> getCacheNamesByClassName(String className);

	/**
	 * Returns every registered cache region name across all classes.
	 *
	 * @return all registered cache names
	 */
	List<String> getAllCacheNames();
}
