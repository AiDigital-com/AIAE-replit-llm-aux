// ─────────────────────────────────────────────────────────────────────────
// SCAFFOLD EXAMPLE — REFERENCE ONLY. DELETE before the first real aggregate
// lands. Run `scripts/strip-scaffold-samples.sh` for one-shot removal.
// See structure/near-production-project-structure.md → "Scaffold sample
// aggregate (reference fixture — MUST be stripped)" for the contract.
// ─────────────────────────────────────────────────────────────────────────
// SampleMapper — reference Entity ↔ Record mapper. One mapper per entity
// per layer (this is the service-layer mapper).
//
// Composition rule: when this entity contains another that has its own
// mapper (e.g. SampleItemEntity → SampleItemMapper), declare
// `@Mapper(config = ServiceMapperConfig.class, uses = SampleItemMapper.class)`
// here and let MapStruct wire the nested call automatically.
// Never duplicate nested conversion code.

package PACKAGE_REPLACE_ME.service.mappers.sample;

import PACKAGE_REPLACE_ME.domain.sample.entities.SampleEntity;
import PACKAGE_REPLACE_ME.service.common.mapping.ServiceMapperConfig;
import PACKAGE_REPLACE_ME.service.sample.models.SampleRecord;
import PACKAGE_REPLACE_ME.service.sample.models.SampleUpdate;
import org.mapstruct.BeanMapping;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;
import org.mapstruct.NullValuePropertyMappingStrategy;

import java.util.List;

/**
 * Converts between the sample JPA entity and service-layer records.
 */
@Mapper(config = ServiceMapperConfig.class)
public interface SampleMapper {

    /**
     * Converts a sample entity to an immutable service record.
     *
     * @param entity persisted sample entity
     * @return service-layer sample record
     */
    SampleRecord toRecord(SampleEntity entity);

    /**
     * Converts a sample record to a JPA entity.
     *
     * @param record service-layer sample record
     * @return persisted sample entity
     */
    SampleEntity toEntity(SampleRecord record);

    /**
     * Converts sample entities to immutable service records.
     *
     * @param entities persisted sample entities
     * @return service-layer sample records
     */
    List<SampleRecord> toRecords(List<SampleEntity> entities);

    /**
     * Copies non-null writable fields from an update model onto an entity.
     *
     * @param update writable service-layer model
     * @param entity managed entity to mutate
     */
    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    void updateEntity(SampleUpdate update, @MappingTarget SampleEntity entity);
}
