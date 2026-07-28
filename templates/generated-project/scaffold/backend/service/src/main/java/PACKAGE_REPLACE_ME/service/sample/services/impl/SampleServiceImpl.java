// ─────────────────────────────────────────────────────────────────────────
// SCAFFOLD EXAMPLE — REFERENCE ONLY. DELETE before the first real aggregate
// lands. Run `scripts/strip-scaffold-samples.sh` for one-shot removal.
// See structure/near-production-project-structure.md → "Scaffold sample
// aggregate (reference fixture — MUST be stripped)" for the contract.
// ─────────────────────────────────────────────────────────────────────────
// SampleServiceImpl — reference impl shape. See SampleService for the
// canonical layout rules.
//
// This file references types (SampleRepository, SampleEntity) that the
// real project must provide in the domain module. The SHAPE — class
// structure, annotations, dependency wiring, error-throwing pattern — is
// what Agent copies.

package PACKAGE_REPLACE_ME.service.sample.services.impl;

import PACKAGE_REPLACE_ME.domain.sample.entities.SampleEntity;
import PACKAGE_REPLACE_ME.domain.sample.repositories.SampleRepository;
import PACKAGE_REPLACE_ME.service.common.error.AppException;
import PACKAGE_REPLACE_ME.service.common.error.ErrorReason;
import PACKAGE_REPLACE_ME.service.common.time.CurrentTime;
import PACKAGE_REPLACE_ME.usagelogging.LogUsage;
import PACKAGE_REPLACE_ME.service.mappers.sample.SampleMapper;
import PACKAGE_REPLACE_ME.service.sample.models.SampleRecord;
import PACKAGE_REPLACE_ME.service.sample.models.SampleUpdate;
import PACKAGE_REPLACE_ME.service.sample.services.SampleService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Default implementation of the reference sample service.
 */
@Service                                              // Only the impl carries @Service.
@RequiredArgsConstructor
public class SampleServiceImpl implements SampleService {

    private final SampleRepository repo;
    private final SampleMapper mapper;
    private final CurrentTime currentTime;

    @Override
    // Auto-logged: the aspect records EVERY public *ServiceImpl method to
    // usage_events with no annotation needed (action derived → "sample.findById").
    public SampleRecord findById(Long id) {
        return repo.findById(id)
            .map(mapper::toRecord)                    // map BEFORE returning (no entity escape)
            .orElseThrow(() -> new AppException(ErrorReason.C001, id));
    }

    @Override
    @LogUsage(action = "sample.update")               // optional: override the auto-derived action name
    public SampleRecord update(Long id, SampleUpdate update) {
        SampleEntity entity = repo.findById(id)
            .orElseThrow(() -> new AppException(ErrorReason.C001, id));
        mapper.updateEntity(update, entity);
        entity.setUpdatedAt(currentTime.nowLocalDateTime());
        return mapper.toRecord(repo.save(entity));
    }
}
