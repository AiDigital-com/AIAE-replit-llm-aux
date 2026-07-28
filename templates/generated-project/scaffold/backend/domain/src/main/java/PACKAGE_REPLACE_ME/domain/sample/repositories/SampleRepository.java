// ─────────────────────────────────────────────────────────────────────────
// SCAFFOLD EXAMPLE — REFERENCE ONLY. DELETE before the first real aggregate
// lands. Run `scripts/strip-scaffold-samples.sh` for one-shot removal.
// See structure/near-production-project-structure.md → "Scaffold sample
// aggregate (reference fixture — MUST be stripped)" for the contract.
// ─────────────────────────────────────────────────────────────────────────
// SampleRepository — reference Spring Data JPA repository for SampleEntity.
// Plural folder name (`repositories/`), one interface per entity. Add custom
// query methods (Spring Data derived queries or @Query JPQL) here.

package PACKAGE_REPLACE_ME.domain.sample.repositories;

import PACKAGE_REPLACE_ME.domain.sample.entities.SampleEntity;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Repository for the reference sample aggregate.
 */
public interface SampleRepository extends JpaRepository<SampleEntity, Long> {
}
