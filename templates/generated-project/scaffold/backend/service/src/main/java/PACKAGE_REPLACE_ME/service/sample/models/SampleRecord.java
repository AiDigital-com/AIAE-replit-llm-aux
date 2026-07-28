// ─────────────────────────────────────────────────────────────────────────
// SCAFFOLD EXAMPLE — REFERENCE ONLY. DELETE before the first real aggregate
// lands. Run `scripts/strip-scaffold-samples.sh` for one-shot removal.
// See structure/near-production-project-structure.md → "Scaffold sample
// aggregate (reference fixture — MUST be stripped)" for the contract.
// ─────────────────────────────────────────────────────────────────────────
// SampleRecord — reference shape for an immutable service-layer DTO.
// Use Java `record`. Fields come from the entity via the mapper.

package PACKAGE_REPLACE_ME.service.sample.models;

import java.time.LocalDateTime;

public record SampleRecord(
    Long id,
    String name,
    LocalDateTime updatedAt                           // LocalDateTime in UTC — see SKILL "Time types"
) { }
