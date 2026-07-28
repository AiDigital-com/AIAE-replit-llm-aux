package PACKAGE_REPLACE_ME.service.common.time;

import java.time.Instant;
import java.time.ZoneOffset;
import org.springframework.stereotype.Service;

/**
 * UTC implementation of the application time boundary.
 */
@Service
public class CurrentTimeImpl implements CurrentTime {

    /**
     * Returns the current instant from the system clock.
     *
     * @return current instant
     */
    @Override
    public Instant nowInstant() {
        return Instant.now();
    }

    /**
     * Returns UTC as the generated-project default time zone.
     *
     * @return UTC zone offset
     */
    @Override
    public ZoneOffset getDefaultTimeZone() {
        return ZoneOffset.UTC;
    }
}
