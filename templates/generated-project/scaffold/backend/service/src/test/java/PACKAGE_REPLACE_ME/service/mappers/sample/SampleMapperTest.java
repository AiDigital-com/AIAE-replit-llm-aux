// SCAFFOLD EXAMPLE — REFERENCE ONLY. DELETE before the first real aggregate
// lands (stripped by scripts/strip-scaffold-samples.sh alongside the sample
// aggregate). Demonstrates testing a MapStruct mapper via its generated impl.
//
// Fixtures use Instancio with every asserted field pinned via set(field(...)),
// per .claude/rules/20-tests.md. Unpinned fields are generated, so adding a
// column to the entity does not send anyone back to edit these tests.
package PACKAGE_REPLACE_ME.service.mappers.sample;

import PACKAGE_REPLACE_ME.domain.sample.entities.SampleEntity;
import PACKAGE_REPLACE_ME.service.sample.models.SampleRecord;
import PACKAGE_REPLACE_ME.service.sample.models.SampleUpdate;
import org.instancio.Instancio;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.instancio.Select.field;

class SampleMapperTest {

    private final SampleMapper mapper = new SampleMapperImpl();

    @Test
    void shouldMapEntityToRecordTest() {
        // Given:
        LocalDateTime updatedAt = LocalDateTime.of(2026, 1, 2, 3, 4, 5);
        SampleEntity entity = Instancio.of(SampleEntity.class)
            .set(field(SampleEntity::getId), 7L)
            .set(field(SampleEntity::getName), "widget")
            .set(field(SampleEntity::getUpdatedAt), updatedAt)
            .create();

        // When:
        SampleRecord record = mapper.toRecord(entity);

        // Then:
        assertThat(record.id()).isEqualTo(7L);
        assertThat(record.name()).isEqualTo("widget");
        assertThat(record.updatedAt()).isEqualTo(updatedAt);
    }

    @Test
    void shouldMapRecordToEntityTest() {
        // Given:
        LocalDateTime updatedAt = LocalDateTime.of(2026, 5, 6, 7, 8, 9);
        SampleRecord record = Instancio.of(SampleRecord.class)
            .set(field(SampleRecord::id), 9L)
            .set(field(SampleRecord::name), "gadget")
            .set(field(SampleRecord::updatedAt), updatedAt)
            .create();

        // When:
        SampleEntity entity = mapper.toEntity(record);

        // Then:
        assertThat(entity.getId()).isEqualTo(9L);
        assertThat(entity.getName()).isEqualTo("gadget");
        assertThat(entity.getUpdatedAt()).isEqualTo(updatedAt);
    }

    @Test
    void shouldMapEntityListToRecordsTest() {
        // Given:
        SampleEntity entity = Instancio.of(SampleEntity.class)
            .set(field(SampleEntity::getId), 1L)
            .set(field(SampleEntity::getName), "a")
            .create();

        // When:
        List<SampleRecord> records = mapper.toRecords(List.of(entity));

        // Then:
        assertThat(records).hasSize(1);
        assertThat(records.get(0).id()).isEqualTo(1L);
        assertThat(records.get(0).name()).isEqualTo("a");
    }

    @Test
    void shouldUpdateEntityFromNonNullUpdateFieldsTest() {
        // Given:
        LocalDateTime untouched = LocalDateTime.of(2026, 1, 1, 0, 0, 0);
        SampleEntity entity = Instancio.of(SampleEntity.class)
            .set(field(SampleEntity::getName), "old")
            .set(field(SampleEntity::getUpdatedAt), untouched)
            .create();

        // When:
        // A one-field request object stays hand-built: running_tests.md allows manual
        // construction where the test needs a tiny scalar input to be explicit.
        mapper.updateEntity(new SampleUpdate("new"), entity);

        // Then:
        assertThat(entity.getName()).isEqualTo("new");
        assertThat(entity.getUpdatedAt()).isEqualTo(untouched);
    }
}
