package PACKAGE_REPLACE_ME.usagelogging.repositories;

import PACKAGE_REPLACE_ME.usagelogging.entities.UsageEventEntity;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Repository for persisted usage logging events.
 */
public interface UsageEventRepository extends JpaRepository<UsageEventEntity, Long> {
}
