package PACKAGE_REPLACE_ME.domain;

import java.util.List;

/**
 * Marker interface indicating that a dictionary repository should be warmed up
 * when the application starts so the L2 cache is populated before the first request.
 *
 * @param <T> the entity class to be warmed up
 */
public interface ToWarmUp<T> {

    /**
     * Retrieves all entities from the database in order to store the result
     * in the L2 cache.
     *
     * @return all dictionary entities
     */
    List<T> findAll();

    /**
     * Returns the class of the entity being warmed up for logging purposes.
     * Required because generic types are erased at runtime.
     *
     * @return the class of the entity being warmed up
     */
    default Class<T> getClazz() {
        throw new IllegalArgumentException("getClazz() must be overridden by the warm-up repository.");
    }
}
