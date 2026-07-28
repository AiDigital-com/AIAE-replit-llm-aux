package PACKAGE_REPLACE_ME.cache;

import PACKAGE_REPLACE_ME.domain.ToWarmUp;
import java.util.List;
import org.junit.jupiter.api.Test;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class CacheWarmUpServiceTest {

    @Test
    void shouldWarmUpCacheWhenEnabledTest() {
        // Given:
        CacheProperties cacheProperties = new CacheProperties();
        cacheProperties.setWarmupEnabled(true);
        ToWarmUp<String> repository = mock();
        when(repository.getClazz()).thenReturn(String.class);
        when(repository.findAll()).thenReturn(List.of("a"));
        CacheWarmUpService service = new CacheWarmUpService(cacheProperties, List.of(repository));

        // When:
        service.initCache();

        // Then:
        verify(repository, times(1)).getClazz();
        verify(repository, times(1)).findAll();
    }

    @Test
    void shouldNotWarmUpCacheWhenDisabledTest() {
        // Given:
        CacheProperties cacheProperties = new CacheProperties();
        cacheProperties.setWarmupEnabled(false);
        ToWarmUp<String> repository = mock();
        CacheWarmUpService service = new CacheWarmUpService(cacheProperties, List.of(repository));

        // When:
        service.initCache();

        // Then:
        verifyNoInteractions(repository);
    }

    @Test
    void shouldWarmUpCacheOnlyOnceTest() {
        // Given:
        CacheProperties cacheProperties = new CacheProperties();
        cacheProperties.setWarmupEnabled(true);
        ToWarmUp<String> repository = mock();
        when(repository.getClazz()).thenReturn(String.class);
        when(repository.findAll()).thenReturn(List.of("a"));
        CacheWarmUpService service = new CacheWarmUpService(cacheProperties, List.of(repository));

        // When:
        service.initCache();
        service.initCache();

        // Then:
        verify(repository, times(1)).getClazz();
        verify(repository, times(1)).findAll();
    }

    @Test
    void shouldCallFindAllForEachRepositoryWhenWarmUpCacheTest() {
        // Given:
        CacheProperties cacheProperties = new CacheProperties();
        cacheProperties.setWarmupEnabled(true);
        ToWarmUp<String> firstRepository = mock();
        ToWarmUp<Integer> secondRepository = mock();
        when(firstRepository.getClazz()).thenReturn(String.class);
        when(firstRepository.findAll()).thenReturn(List.of("a"));
        when(secondRepository.getClazz()).thenReturn(Integer.class);
        when(secondRepository.findAll()).thenReturn(List.of(1));
        CacheWarmUpService service = new CacheWarmUpService(
            cacheProperties,
            List.of(firstRepository, secondRepository)
        );

        // When:
        service.warmUpCache();

        // Then:
        verify(firstRepository, times(1)).getClazz();
        verify(firstRepository, times(1)).findAll();
        verify(secondRepository, times(1)).getClazz();
        verify(secondRepository, times(1)).findAll();
    }
}
