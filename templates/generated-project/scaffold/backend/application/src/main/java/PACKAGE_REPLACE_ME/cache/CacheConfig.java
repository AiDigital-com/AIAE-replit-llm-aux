package PACKAGE_REPLACE_ME.cache;

import PACKAGE_REPLACE_ME.domain.ToWarmUp;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.List;
import javax.cache.Caching;
import org.springframework.boot.autoconfigure.orm.jpa.HibernatePropertiesCustomizer;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.jcache.JCacheCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Registers the L2 cache warm-up infrastructure.
 *
 * <p>Actual cache regions and query hints are configured via
 * {@code src/main/resources/ehcache.xml} and Hibernate properties in
 * {@code application.yml}. Hibernate and Spring must use this exact JCache
 * manager instance; otherwise cross-node invalidation can clear a different
 * manager while Hibernate continues serving stale L2 entries.
 */
@Configuration
@EnableCaching
@EnableConfigurationProperties(CacheProperties.class)
public class CacheConfig {

    /**
     * Creates the single JSR-107 cache manager shared by Hibernate and Spring.
     *
     * @return the ehcache.xml-configured manager
     */
    @Bean(destroyMethod = "close")
    javax.cache.CacheManager jCacheManager() {
        try {
            var resource = getClass().getClassLoader().getResource("ehcache.xml");
            if (resource == null) {
                throw new IllegalStateException("ehcache.xml is missing from the application classpath");
            }
            URI configUri = resource.toURI();
            return Caching.getCachingProvider()
                .getCacheManager(configUri, getClass().getClassLoader());
        } catch (URISyntaxException exception) {
            throw new IllegalStateException("Cannot resolve ehcache.xml", exception);
        }
    }

    /**
     * Exposes the shared JCache manager through Spring's cache abstraction.
     *
     * @param jCacheManager shared JSR-107 manager
     * @return Spring cache manager backed by the same Ehcache regions
     */
    @Bean
    CacheManager cacheManager(javax.cache.CacheManager jCacheManager) {
        return new JCacheCacheManager(jCacheManager);
    }

    /**
     * Forces Hibernate L2 to use the same JCache manager exposed to Spring.
     *
     * @param jCacheManager shared JSR-107 manager
     * @return Hibernate property customizer
     */
    @Bean
    HibernatePropertiesCustomizer sharedJCacheManagerCustomizer(
        javax.cache.CacheManager jCacheManager
    ) {
        return properties ->
            properties.put("hibernate.javax.cache.cache_manager", jCacheManager);
    }

    /**
     * Creates the cache warm-up service that loads dictionaries on startup.
     *
     * @param cacheProperties warm-up configuration
     * @param repositoriesToWarmUp all repositories implementing {@link ToWarmUp}
     * @return the warm-up service bean
     */
    @Bean
    public CacheWarmUpService cacheWarmUpService(
        CacheProperties cacheProperties,
        List<ToWarmUp<?>> repositoriesToWarmUp
    ) {
        return new CacheWarmUpService(cacheProperties, repositoriesToWarmUp);
    }
}
