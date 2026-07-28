package PACKAGE_REPLACE_ME.cachemanagement.registry;

import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Default {@link CacheNamesByClassService}. Flattens the
 * {@link CacheNamesByClassRegistry} into a collision-safe lookup keyed by
 * fully qualified class name once at construction.
 */
@Service
public class CacheNamesByClassServiceImpl implements CacheNamesByClassService {

	private final Map<String, List<String>> cacheNamesByClassName;

	/**
	 * Builds the simple-name → cache-names lookup from the registry.
	 *
	 * @param registry the application's cache-names registry
	 */
	public CacheNamesByClassServiceImpl(CacheNamesByClassRegistry registry) {
		Map<String, List<String>> lookup = new HashMap<>();
		for (Map.Entry<Class<?>, List<String>> entry : registry.cacheNamesByClassMap().entrySet()) {
			lookup.computeIfAbsent(entry.getKey().getName(), key -> new ArrayList<>())
					.addAll(entry.getValue());
		}
		this.cacheNamesByClassName = lookup;
	}

	@Override
	public List<String> getCacheNamesByClassName(String className) {
		return cacheNamesByClassName.getOrDefault(className, List.of());
	}

	@Override
	public List<String> getAllCacheNames() {
		return cacheNamesByClassName.values().stream()
				.flatMap(Collection::stream)
				.toList();
	}
}
