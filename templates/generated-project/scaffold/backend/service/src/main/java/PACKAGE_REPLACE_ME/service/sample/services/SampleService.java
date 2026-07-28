// ─────────────────────────────────────────────────────────────────────────
// SCAFFOLD EXAMPLE — REFERENCE ONLY. DELETE before the first real aggregate
// lands. Run `scripts/strip-scaffold-samples.sh` for one-shot removal.
// See structure/near-production-project-structure.md → "Scaffold sample
// aggregate (reference fixture — MUST be stripped)" for the contract.
// ─────────────────────────────────────────────────────────────────────────
// SampleService — reference shape Agent copies/renames for every new
// service. Demonstrates the canonical service-layer layout:
//
//   service/<base>/service/<aggregate>/
//     services/<X>Service.java         ← interface (this file)
//     services/impl/<X>ServiceImpl.java ← @Service impl
//     mappers/<X>Mapper.java            ← Entity ↔ Record, one per entity
//     models/<X>Record.java             ← immutable record (output)
//     models/<X>Update.java             ← request payload (input)
//
// Hard rules (see backend-java-feature SKILL):
//   - Interface and impl in DIFFERENT packages (services/ vs services/impl/).
//   - Only the impl carries @Service. Callers inject the interface.
//   - Optional runtime instrumentation belongs on the impl side; interfaces
//     should not carry implementation/runtime annotations.
//   - Methods return Record / page-of-Record, never Entity.
//   - Throw AppException with ErrorReason — never a per-domain enum.
//
// Delete this whole sample/ tree once the project has a real aggregate.

package PACKAGE_REPLACE_ME.service.sample.services;

import PACKAGE_REPLACE_ME.service.sample.models.SampleRecord;
import PACKAGE_REPLACE_ME.service.sample.models.SampleUpdate;

/**
 * Reference service contract for the sample aggregate.
 */
public interface SampleService {

    /**
     * Reads a sample by id.
     *
     * @param id sample identifier
     * @return matching sample record
     */
    SampleRecord findById(Long id);

    /**
     * Updates a sample by id.
     *
     * @param id sample identifier
     * @param update writable sample fields
     * @return updated sample record
     */
    SampleRecord update(Long id, SampleUpdate update);
}
