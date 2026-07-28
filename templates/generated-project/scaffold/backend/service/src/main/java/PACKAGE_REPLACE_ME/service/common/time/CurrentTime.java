package PACKAGE_REPLACE_ME.service.common.time;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;

/**
 * Provides application time from an injectable boundary.
 */
public interface CurrentTime {

    LocalTime MAX_TIME = LocalTime.MAX.truncatedTo(ChronoUnit.MICROS);

    /**
     * Returns the current instant.
     *
     * @return current instant from the application clock
     */
    Instant nowInstant();

    /**
     * Returns the current local date-time in the default application zone.
     *
     * @return current local date-time
     */
    default LocalDateTime nowLocalDateTime() {
        return LocalDateTime.ofInstant(this.nowInstant(), this.getDefaultTimeZone());
    }

    /**
     * Returns the current local date in the default application zone.
     *
     * @return current local date
     */
    default LocalDate nowLocalDate() {
        return this.nowLocalDateTime().toLocalDate();
    }

    /**
     * Returns the current local time in the default application zone.
     *
     * @return current local time
     */
    default LocalTime nowLocalTime() {
        return this.nowLocalDateTime().toLocalTime();
    }

    /**
     * Returns the default zone used for local date/time values.
     *
     * @return default application zone offset
     */
    ZoneOffset getDefaultTimeZone();
}
