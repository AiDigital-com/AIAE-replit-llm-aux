package PACKAGE_REPLACE_ME.cachemanagement.config;

import java.time.Duration;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Typed configuration for database-backed cross-node cache invalidation.
 */
@Component
@ConfigurationProperties(prefix = "app.cache-management")
@Getter
public class CacheManagementProperties {

	@Setter
	private boolean verifyRegistry;
	@Setter
	private boolean cleanupEnabled;
	private int batchSize = 500;
	private int maxBatchesPerPoll = 20;
	private Duration retention = Duration.ofDays(7);

	/**
	 * Sets the maximum events fetched per database query.
	 *
	 * @param batchSize positive page size
	 */
	public void setBatchSize(int batchSize) {
		if (batchSize < 1) {
			throw new IllegalArgumentException("batch-size must be positive");
		}
		this.batchSize = batchSize;
	}

	/**
	 * Sets the bounded number of pages processed by one scheduled firing.
	 *
	 * @param maxBatchesPerPoll positive page count
	 */
	public void setMaxBatchesPerPoll(int maxBatchesPerPoll) {
		if (maxBatchesPerPoll < 1) {
			throw new IllegalArgumentException("max-batches-per-poll must be positive");
		}
		this.maxBatchesPerPoll = maxBatchesPerPoll;
	}

	/**
	 * Sets how long durable invalidation rows remain available for replay.
	 *
	 * @param retention positive retention duration
	 */
	public void setRetention(Duration retention) {
		if (retention == null || retention.isNegative() || retention.isZero()) {
			throw new IllegalArgumentException("retention must be positive");
		}
		this.retention = retention;
	}
}
