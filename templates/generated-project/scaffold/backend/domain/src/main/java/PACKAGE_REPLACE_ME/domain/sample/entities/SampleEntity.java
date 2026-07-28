// ─────────────────────────────────────────────────────────────────────────
// SCAFFOLD EXAMPLE — REFERENCE ONLY. DELETE before the first real aggregate
// lands. Run `scripts/strip-scaffold-samples.sh` for one-shot removal.
// See structure/near-production-project-structure.md → "Scaffold sample
// aggregate (reference fixture — MUST be stripped)" for the contract.
// ─────────────────────────────────────────────────────────────────────────
// SampleEntity — reference JPA entity for the sample aggregate. Plain
// POJO + getters/setters via Lombok; no business logic, no service
// imports (domain is a leaf module). Service-layer MapStruct mappers copy
// writable fields from SampleUpdate — entity does NOT accept SampleUpdate
// (would force domain → service edge).
//
// Delete this whole sample tree when the project has a real aggregate.

package PACKAGE_REPLACE_ME.domain.sample.entities;

import PACKAGE_REPLACE_ME.domain.common.entities.IdAwareEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/**
 * Persistence model for the reference sample aggregate.
 */
@Entity
@Table(name = "samples")
@Getter
@Setter
@NoArgsConstructor
public class SampleEntity extends IdAwareEntity {

    @Column(nullable = false)
    private String name;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
}
