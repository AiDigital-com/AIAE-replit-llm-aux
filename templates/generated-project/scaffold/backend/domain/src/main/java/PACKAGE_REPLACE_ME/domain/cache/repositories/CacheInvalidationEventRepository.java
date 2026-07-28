package PACKAGE_REPLACE_ME.domain.cache.repositories;

import PACKAGE_REPLACE_ME.domain.cache.entities.CacheInvalidationEventEntity;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

/**
 * Persistence boundary for the shared cache-invalidation outbox.
 */
public interface CacheInvalidationEventRepository
		extends JpaRepository<CacheInvalidationEventEntity, Long> {

	/**
	 * Reads one ordered page after the consumer's last processed sequence.
	 *
	 * @param sequence exclusive lower event-ID bound
	 * @param pageable page size and ordering boundary
	 * @return events ordered by increasing ID
	 */
	List<CacheInvalidationEventEntity> findByIdGreaterThanOrderByIdAsc(
			long sequence,
			Pageable pageable);

	/**
	 * Deletes outbox rows older than the retention cutoff.
	 *
	 * @param cutoff exclusive creation-time upper bound
	 * @return number of deleted rows
	 */
	@Modifying
	@Query("delete from CacheInvalidationEventEntity event where event.createdAt < :cutoff")
	int deleteCreatedBefore(@Param("cutoff") Instant cutoff);
}
