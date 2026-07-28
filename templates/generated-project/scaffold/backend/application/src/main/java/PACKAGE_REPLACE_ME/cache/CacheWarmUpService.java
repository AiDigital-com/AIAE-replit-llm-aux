package PACKAGE_REPLACE_ME.cache;

import PACKAGE_REPLACE_ME.domain.ToWarmUp;
import java.util.List;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.ContextRefreshedEvent;
import org.springframework.context.event.EventListener;

/**
 * Warms up L2 cache regions for repositories implementing {@link ToWarmUp}
 * when the application starts.
 */
@RequiredArgsConstructor
public class CacheWarmUpService {

    private static final Logger LOG = LoggerFactory.getLogger(CacheWarmUpService.class);

    private volatile boolean isInitialized;

    private final CacheProperties cacheProperties;
    private final List<ToWarmUp<?>> repositoriesToWarmUp;

    /**
     * Triggers cache warm-up once the Spring context is refreshed.
     *
     * <p>Guarded by a double-checked flag so multiple context events only run
     * warm-up a single time.
     */
    @EventListener(ContextRefreshedEvent.class)
    public void initCache() {
        if (cacheProperties.isWarmupEnabled() && !isInitialized) {
            synchronized (this) {
                if (!isInitialized) {
                    warmUpCache();
                    isInitialized = true;
                }
            }
        }
    }

    /**
     * Loads every registered dictionary once so Hibernate L2 cache regions
     * are populated before traffic arrives.
     */
    void warmUpCache() {
        int repositoriesToWarmUpSize = repositoriesToWarmUp.size();
        LOG.info(
            "Starting warmup of {} dictionaries:\n{}",
            repositoriesToWarmUpSize,
            repositoriesToWarmUp.stream()
                .map(toWarmUp -> toWarmUp.getClazz().getSimpleName())
                .collect(Collectors.joining("\n"))
        );
        // Deliberately sequential: parallel startup reads multiply connection
        // pressure on one node and can create a cross-node cache stampede when
        // several instances restart together.
        repositoriesToWarmUp.forEach(ToWarmUp::findAll);
        LOG.info("Finishing warmup of {} dictionaries.", repositoriesToWarmUpSize);
    }
}
