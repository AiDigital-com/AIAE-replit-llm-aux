// Spring Boot entrypoint. Generated apps put this in
//   backend/application/src/main/java/com/aidigital/<appname>/Application.java
// Replace PACKAGE_REPLACE_ME with com.aidigital.<app-name-package>.

package PACKAGE_REPLACE_ME;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class Application {

    /**
     * Starts the Spring Boot application.
     *
     * @param args command-line arguments passed by the runtime
     */
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
