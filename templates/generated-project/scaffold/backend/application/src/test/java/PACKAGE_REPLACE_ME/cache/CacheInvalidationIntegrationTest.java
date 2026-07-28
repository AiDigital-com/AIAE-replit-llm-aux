package PACKAGE_REPLACE_ME.cache;

import PACKAGE_REPLACE_ME.cachemanagement.event.CacheInvalidationEventService;
import PACKAGE_REPLACE_ME.domain.cache.repositories.CacheInvalidationEventRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.orm.jpa.HibernatePropertiesCustomizer;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.cache.jcache.JCacheCacheManager;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Pins the transactional outbox and shared-cache-manager correctness contract.
 */
@SpringBootTest
@ActiveProfiles("test")
class CacheInvalidationIntegrationTest {

	@MockitoBean
	private JwtDecoder jwtDecoder;

	@Autowired
	private CacheInvalidationEventService eventService;

	@Autowired
	private CacheInvalidationEventRepository repository;

	@Autowired
	private PlatformTransactionManager transactionManager;

	@Autowired
	private javax.cache.CacheManager jCacheManager;

	@Autowired
	private org.springframework.cache.CacheManager springCacheManager;

	@Autowired
	@Qualifier("sharedJCacheManagerCustomizer")
	private HibernatePropertiesCustomizer hibernateCustomizer;

	@BeforeEach
	void clearEvents() {
		repository.deleteAll();
	}

	@Test
	void shouldCommitMutationAndInvalidationAtomicallyTest() {
		TransactionTemplate transaction = new TransactionTemplate(transactionManager);

		transaction.executeWithoutResult(status ->
				eventService.publishUpdateEvent("example.Team"));

		assertThat(repository.count()).isEqualTo(1L);
	}

	@Test
	void shouldRollbackInvalidationWithMutationTransactionTest() {
		TransactionTemplate transaction = new TransactionTemplate(transactionManager);

		transaction.executeWithoutResult(status -> {
			eventService.publishUpdateEvent("example.Team");
			status.setRollbackOnly();
		});

		assertThat(repository.count()).isZero();
	}

	@Test
	void shouldRejectPublicationOutsideMutationTransactionTest() {
		assertThatThrownBy(() -> eventService.publishUpdateEvent("example.Team"))
				.isInstanceOf(org.springframework.transaction.IllegalTransactionStateException.class);
	}

	@Test
	void shouldShareTheExactJCacheManagerWithSpringAndHibernateTest() {
		assertThat(springCacheManager).isInstanceOf(JCacheCacheManager.class);
		assertThat(((JCacheCacheManager) springCacheManager).getCacheManager())
				.isSameAs(jCacheManager);

		Map<String, Object> hibernateProperties = new HashMap<>();
		hibernateCustomizer.customize(hibernateProperties);
		assertThat(hibernateProperties.get("hibernate.javax.cache.cache_manager"))
				.isSameAs(jCacheManager);
	}
}
