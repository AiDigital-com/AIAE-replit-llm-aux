package PACKAGE_REPLACE_ME.domain.cache.entities;

import PACKAGE_REPLACE_ME.domain.common.entities.IdAwareEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.time.Instant;

/**
 * Durable outbox row announcing that data feeding one or more local cache
 * regions changed. The generated identity is the poller's ordering cursor.
 */
@Entity
@Table(name = "cache_invalidation_event")
public class CacheInvalidationEventEntity extends IdAwareEntity {

	@Column(name = "tracked_class", nullable = false)
	private String trackedClass;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	protected CacheInvalidationEventEntity() {
	}

	public CacheInvalidationEventEntity(String trackedClass, Instant createdAt) {
		this.trackedClass = trackedClass;
		this.createdAt = createdAt;
	}

	public String getTrackedClass() {
		return trackedClass;
	}

	public void setTrackedClass(String trackedClass) {
		this.trackedClass = trackedClass;
	}

	public Instant getCreatedAt() {
		return createdAt;
	}

	public void setCreatedAt(Instant createdAt) {
		this.createdAt = createdAt;
	}
}
