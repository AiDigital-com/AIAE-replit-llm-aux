package PACKAGE_REPLACE_ME.cachemanagement.updater;

/**
 * Clears cache regions in response to an invalidation event.
 */
public interface CacheUpdaterService {

	/**
	 * Clears every cache region registered for the given fully qualified class name.
	 *
	 * @param className the changed class's fully qualified name
	 */
	void clearCachesForClass(String className);

	/**
	 * Clears every cache region with the given name (across all cache managers).
	 *
	 * @param cacheName the cache region name
	 */
	void clearCache(String cacheName);
}
