// ─────────────────────────────────────────────────────────────────────────
// SCAFFOLD EXAMPLE — REFERENCE ONLY. DELETE before the first real aggregate
// lands. Run `scripts/strip-scaffold-samples.sh` for one-shot removal.
// See structure/near-production-project-structure.md → "Scaffold sample
// aggregate (reference fixture — MUST be stripped)" for the contract.
// ─────────────────────────────────────────────────────────────────────────
// SampleUpdate — reference shape for a service-layer input record. Carries
// only the fields a caller may change. Validation lives on the request
// DTO (in application/) AND on the entity via bean-validation; this
// record is the plain Java carrier between them.

package PACKAGE_REPLACE_ME.service.sample.models;

public record SampleUpdate(
    String name
) { }
