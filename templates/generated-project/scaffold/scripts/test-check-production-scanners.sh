#!/usr/bin/env bash
#
# test-check-production-scanners.sh — contract tests for production Java scanners.
#
# Every case asserts the scanner's own diagnostic, not just its exit status. A
# scanner with a syntax error, a missing interpreter, or a typo'd path also exits
# non-zero, so an exit-code-only negative test passes while the scanner checks
# nothing. Measured here: replacing check-production-magic-values.sh with invalid
# Bash left its negative case reporting a pass.
#
# This file stays in the template repository — materialize-project.sh ships only
# the runtime scripts, so a generated project never needs tests/gates/lib.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_ROOT="$(cd "${SCAFFOLD}/../../.." && pwd)"
LIB="${SCRIPT_DIR}/lib"

# shellcheck source=../../../../tests/gates/lib/assert.sh
. "${TEMPLATE_ROOT}/tests/gates/lib/assert.sh"

# The scanners resolve their arguments relative to the working directory, so each
# case runs inside the tree it inspects.
# `env` so a case may prefix VAR=value assignments, as the structure-lint cases do
# with STRUCTURE_LINT_ALLOW_SAMPLE=1. Without it those become a command name.
in_dir() { local dir="$1"; shift; ( cd "${dir}" && env "$@" ); }
accept() { local label="$1" dir="$2"; shift 2; gate_accepts "${label}" "${dir}" -- in_dir "${dir}" "$@"; }
reject() { local label="$1" dir="$2" diagnostic="$3"; shift 3; gate_rejects "${label}" "${dir}" "${diagnostic}" -- in_dir "${dir}" "$@"; }

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
JAVA_DIR="${WORK}/backend/demo/src/main/java/com/example/demo"
mkdir -p "${JAVA_DIR}"

echo "==> magic scanner accepts named constants"
cat > "${JAVA_DIR}/OnlyGood.java" <<'EOF'
package com.example.demo;
public class OnlyGood {
    private static final String CLAIM = "user_id";
    public void run() {
        doWork(CLAIM);
    }
    private void doWork(String claim) {}
}
EOF
accept "named constant allowed" "${WORK}" bash "${LIB}/check-production-magic-values.sh" backend/demo/src/main/java

echo "==> magic scanner rejects inline literals"
rm -f "${JAVA_DIR}/OnlyGood.java"
cat > "${JAVA_DIR}/OnlyBad.java" <<'EOF'
package com.example.demo;
public class OnlyBad {
    public void run() {
        check("user_id");
    }
    private void check(String c) {}
}
EOF
reject "inline literal rejected" "${WORK}" "check-production-magic-values: FAIL" bash "${LIB}/check-production-magic-values.sh" backend/demo/src/main/java

echo "==> static scanner detects project static methods"
rm -f "${JAVA_DIR}/"*.java
cat > "${JAVA_DIR}/StaticBad.java" <<'EOF'
package com.example.demo;
public class StaticBad {
    private static String helper(String v) {
        return v;
    }
}
EOF
reject "static helper rejected" "${WORK}" "check-production-static-methods: FAIL" bash "${LIB}/check-production-static-methods.sh" backend/demo/src/main/java

echo "==> static scanner accepts constants and main"
rm -f "${JAVA_DIR}/StaticBad.java"
cat > "${JAVA_DIR}/StaticGood.java" <<'EOF'
package com.example.demo;
public class StaticGood {
    private static final String OK = "x";
    public static void main(String[] args) {}
}
EOF
accept "constants and main allowed" "${WORK}" bash "${LIB}/check-production-static-methods.sh" backend/demo/src/main/java

echo "==> current-time scanner rejects direct now calls"
rm -f "${JAVA_DIR}/"*.java
cat > "${JAVA_DIR}/TimeBad.java" <<'EOF'
package com.example.demo;
import java.time.LocalDateTime;
public class TimeBad {
    public LocalDateTime run() {
        return LocalDateTime.now();
    }
}
EOF
reject "direct now() rejected" "${WORK}" "check-production-current-time: FAIL" bash "${LIB}/check-production-current-time.sh" backend/demo/src/main/java

echo "==> current-time scanner accepts CurrentTime boundary"
rm -f "${JAVA_DIR}/TimeBad.java"
cat > "${JAVA_DIR}/TimeGood.java" <<'EOF'
package com.example.demo;
import java.time.LocalDateTime;
public class TimeGood {
    private final CurrentTime currentTime;
    public TimeGood(CurrentTime currentTime) {
        this.currentTime = currentTime;
    }
    public LocalDateTime run() {
        return currentTime.nowLocalDateTime();
    }
    interface CurrentTime {
        LocalDateTime nowLocalDateTime();
    }
}
EOF
cat > "${JAVA_DIR}/CurrentTimeImpl.java" <<'EOF'
package com.example.demo;
import java.time.Instant;
public class CurrentTimeImpl {
    public Instant nowInstant() {
        return Instant.now();
    }
}
EOF
accept "CurrentTime boundary allowed" "${WORK}" bash "${LIB}/check-production-current-time.sh" backend/demo/src/main/java

echo "==> manual-mapping scanner rejects entity setter chains"
rm -f "${JAVA_DIR}/"*.java
cat > "${JAVA_DIR}/ManualMappingBad.java" <<'EOF'
package com.example.demo;
public class ManualMappingBad {
    public CaseStudyEntity create(CaseStudyModel model) {
        CaseStudyEntity entity = new CaseStudyEntity();
        entity.setTitle(model.title());
        entity.setStatus("SUBMITTED");
        return entity;
    }
    record CaseStudyModel(String title) {}
    static class CaseStudyEntity {
        void setTitle(String title) {}
        void setStatus(String status) {}
    }
}
EOF
reject "entity setter chain rejected" "${WORK}" "check-production-manual-mapping: FAIL" bash "${LIB}/check-production-manual-mapping.sh" backend/demo/src/main/java

echo "==> manual-mapping scanner accepts MapStruct boundary plus technical timestamp"
rm -f "${JAVA_DIR}/ManualMappingBad.java"
cat > "${JAVA_DIR}/ManualMappingGood.java" <<'EOF'
package com.example.demo;
import java.time.LocalDateTime;
public class ManualMappingGood {
    private final CaseStudyMapper mapper;
    private final CurrentTime currentTime;
    public ManualMappingGood(CaseStudyMapper mapper, CurrentTime currentTime) {
        this.mapper = mapper;
        this.currentTime = currentTime;
    }
    public CaseStudyEntity create(CaseStudyModel model) {
        CaseStudyEntity entity = mapper.toEntity(model);
        entity.setCreatedAt(currentTime.nowLocalDateTime());
        return entity;
    }
    record CaseStudyModel(String title) {}
    interface CaseStudyMapper {
        CaseStudyEntity toEntity(CaseStudyModel model);
    }
    interface CurrentTime {
        LocalDateTime nowLocalDateTime();
    }
    static class CaseStudyEntity {
        void setCreatedAt(LocalDateTime createdAt) {}
    }
}
EOF
accept "MapStruct boundary allowed" "${WORK}" bash "${LIB}/check-production-manual-mapping.sh" backend/demo/src/main/java

OPENAPI_DIR="${WORK}/backend/application/src/main/resources/api/v1/specs"
FRONTEND_SCHEMA_DIR="${WORK}/frontend/src/shared/api/generated"
mkdir -p "${OPENAPI_DIR}" "${FRONTEND_SCHEMA_DIR}"

openapi_base() {
  cat > "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
openapi: 3.0.3
info:
  title: Demo
  version: 1.0.0
paths: {}
components:
  schemas:
EOF
}

echo "==> OpenAPI input constraint scanner accepts constrained and intentionally unconstrained inputs"
cat > "${OPENAPI_DIR}/input-constraints.yaml" <<'EOF'
openapi: 3.0.3
info: { title: Demo, version: 1.0.0 }
paths:
  /api/v1/widgets:
    get:
      operationId: listWidgets
      parameters:
        - name: query
          in: query
          schema: { type: string, minLength: 2, maxLength: 100 }
        - name: cursor
          in: query
          x-unconstrained-reason: Opaque cursor is validated by the pagination boundary.
          schema: { type: string }
      responses: { '200': { description: OK } }
components: { schemas: {} }
EOF
accept "constrained and documented-unconstrained inputs allowed" "${WORK}" python3 "${LIB}/check-openapi-input-constraints.py" backend/application/src/main/resources/api/v1/specs/input-constraints.yaml

echo "==> OpenAPI input constraint scanner accepts a referenced versioned enum"
cat > "${OPENAPI_DIR}/referenced-enum-input.yaml" <<'EOF'
openapi: 3.0.3
info: { title: Demo, version: 1.0.0 }
paths:
  /api/v1/widgets:
    post:
      operationId: createWidget
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateWidgetRequestV1'
      responses: { '201': { description: Created } }
components:
  schemas:
    CreateWidgetRequestV1:
      type: object
      properties:
        role:
          $ref: '#/components/schemas/WidgetRoleV1'
    WidgetRoleV1:
      type: string
      enum: [viewer, editor]
EOF
accept "referenced versioned enum input allowed" "${WORK}" python3 "${LIB}/check-openapi-input-constraints.py" backend/application/src/main/resources/api/v1/specs/referenced-enum-input.yaml

echo "==> OpenAPI input constraint scanner rejects unconstrained input"
sed '/minLength: 2, maxLength: 100/d' "${OPENAPI_DIR}/input-constraints.yaml" > "${OPENAPI_DIR}/unconstrained-input.yaml"
reject "unconstrained parameter rejected" "${WORK}" "check-openapi-input-constraints: FAIL" python3 "${LIB}/check-openapi-input-constraints.py" backend/application/src/main/resources/api/v1/specs/unconstrained-input.yaml

VALIDATION_TEST_ROOT="${WORK}/validation-test-project"
mkdir -p "${VALIDATION_TEST_ROOT}/backend/application/src/main/resources/api/v1/specs" \
  "${VALIDATION_TEST_ROOT}/backend/application/src/test/java/com/example/demo/controllers"
cp "${OPENAPI_DIR}/input-constraints.yaml" "${VALIDATION_TEST_ROOT}/backend/application/src/main/resources/api/v1/specs/openapi.yaml"
cat > "${VALIDATION_TEST_ROOT}/backend/application/src/test/java/com/example/demo/controllers/WidgetControllerTest.java" <<'EOF'
class WidgetControllerTest {
    void rejectsInvalidQuery() {
        status().isBadRequest();
    }
}
EOF
echo "==> API validation test scanner accepts negative 400 coverage"
accept "negative 400 validation coverage allowed" "${VALIDATION_TEST_ROOT}" python3 "${LIB}/check-api-validation-tests.py" "${VALIDATION_TEST_ROOT}"
rm -f "${VALIDATION_TEST_ROOT}/backend/application/src/test/java/com/example/demo/controllers/WidgetControllerTest.java"
echo "==> API validation test scanner rejects missing negative 400 coverage"
reject "missing negative 400 validation coverage rejected" "${VALIDATION_TEST_ROOT}" "check-api-validation-tests: FAIL" python3 "${LIB}/check-api-validation-tests.py" "${VALIDATION_TEST_ROOT}"

cat > "${VALIDATION_TEST_ROOT}/backend/application/src/main/resources/api/v1/specs/openapi.yaml" <<'EOF'
openapi: 3.0.3
info: { title: Demo, version: 1.0.0 }
paths:
  /api/v1/widgets:
    post:
      operationId: createWidget
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateWidgetRequestV1'
      responses: { '201': { description: Created } }
components:
  schemas:
    CreateWidgetRequestV1:
      type: object
      properties:
        name: { type: string, minLength: 2, maxLength: 100 }
EOF
echo "==> API validation test scanner dereferences constrained component request schemas"
reject "constrained component request without negative 400 coverage rejected" "${VALIDATION_TEST_ROOT}" "check-api-validation-tests: FAIL" python3 "${LIB}/check-api-validation-tests.py" "${VALIDATION_TEST_ROOT}"
cat > "${VALIDATION_TEST_ROOT}/backend/application/src/test/java/com/example/demo/controllers/WidgetControllerTest.java" <<'EOF'
class WidgetControllerTest {
    void rejectsInvalidRequestBody() {
        status().isBadRequest();
    }
}
EOF
accept "constrained component request with negative 400 coverage allowed" "${VALIDATION_TEST_ROOT}" python3 "${LIB}/check-api-validation-tests.py" "${VALIDATION_TEST_ROOT}"

echo "==> OpenAPI strict scanner accepts closed DTOs and typed dynamic fields"
openapi_base
cat >> "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
    DemoResponseV1:
      type: object
      additionalProperties: false
      required: [id, flags]
      properties:
        id:
          type: integer
          format: int64
        flags:
          type: object
          additionalProperties:
            type: boolean
EOF
: > "${FRONTEND_SCHEMA_DIR}/schema.d.ts"
accept "closed OpenAPI DTO allowed" "${WORK}" bash "${LIB}/check-openapi-strict-schemas.sh" backend/application/src/main/resources/api/v1/specs/openapi.yaml frontend/src/shared/api/generated/schema.d.ts

echo "==> OpenAPI strict scanner rejects object DTOs without explicit closure"
openapi_base
cat >> "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
    MissingClosureResponseV1:
      type: object
      properties:
        id:
          type: integer
          format: int64
EOF
reject "object DTO without explicit closure rejected" "${WORK}" "top-level component object schemas must be closed" bash "${LIB}/check-openapi-strict-schemas.sh" backend/application/src/main/resources/api/v1/specs/openapi.yaml frontend/src/shared/api/generated/schema.d.ts

echo "==> OpenAPI strict scanner rejects loose top-level DTOs"
openapi_base
cat >> "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
    LooseResponseV1:
      type: object
      additionalProperties: true
EOF
reject "loose top-level DTO rejected" "${WORK}" "top-level component object schemas must be closed" bash "${LIB}/check-openapi-strict-schemas.sh" backend/application/src/main/resources/api/v1/specs/openapi.yaml frontend/src/shared/api/generated/schema.d.ts

echo "==> OpenAPI strict scanner allows named dynamic helper schemas"
openapi_base
cat >> "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
    JsonMetadataV1:
      type: object
      additionalProperties: true
EOF
cat > "${FRONTEND_SCHEMA_DIR}/schema.d.ts" <<'EOF'
export interface components {
  schemas: {
    JsonMetadataV1: {
      [key: string]: unknown;
    };
  };
}
EOF
accept "named dynamic helper schema allowed" "${WORK}" bash "${LIB}/check-openapi-strict-schemas.sh" backend/application/src/main/resources/api/v1/specs/openapi.yaml frontend/src/shared/api/generated/schema.d.ts

echo "==> OpenAPI strict scanner rejects generated unknown index signatures for business DTOs"
openapi_base
cat >> "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
    ClosedResponseV1:
      type: object
      additionalProperties: false
      properties:
        id:
          type: integer
          format: int64
EOF
cat > "${FRONTEND_SCHEMA_DIR}/schema.d.ts" <<'EOF'
export interface components {
  schemas: {
    ClosedResponseV1: {
      id?: number;
      [key: string]: unknown;
    };
  };
}
EOF
reject "business DTO unknown index signature rejected" "${WORK}" "generated frontend types contain unknown index signatures" bash "${LIB}/check-openapi-strict-schemas.sh" backend/application/src/main/resources/api/v1/specs/openapi.yaml frontend/src/shared/api/generated/schema.d.ts


echo "==> OpenAPI enum scanner accepts standalone versioned enum schemas"
openapi_base
cat >> "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
    UserRoleCodeV1:
      type: string
      description: User role code.
      enum: [admin, teamlead, member]
    UserPermissionSnapshotV1:
      type: object
      additionalProperties: false
      required: [roleCode]
      properties:
        roleCode:
          description: Assigned user role code.
          $ref: '#/components/schemas/UserRoleCodeV1'
EOF
accept "standalone versioned enum schema allowed" "${WORK}" bash "${LIB}/check-openapi-enums.sh" backend/application/src/main/resources/api/v1/specs/openapi.yaml

echo "==> OpenAPI enum scanner rejects inline property enums"
openapi_base
cat >> "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
    UserPermissionSnapshotV1:
      type: object
      additionalProperties: false
      properties:
        roleCode:
          type: string
          enum: [admin, teamlead, member]
EOF
reject "inline property enum rejected" "${WORK}" "check-openapi-enums: FAIL" bash "${LIB}/check-openapi-enums.sh" backend/application/src/main/resources/api/v1/specs/openapi.yaml

echo "==> OpenAPI enum scanner rejects inline query parameter enums"
openapi_base
cat > "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
openapi: 3.0.3
info:
  title: Demo
  version: 1.0.0
paths:
  /users:
    get:
      parameters:
        - in: query
          name: roleCode
          schema:
            type: string
            enum: [admin, member]
      responses:
        '200':
          description: OK
components:
  schemas: {}
EOF
reject "inline query parameter enum rejected" "${WORK}" "check-openapi-enums: FAIL" bash "${LIB}/check-openapi-enums.sh" backend/application/src/main/resources/api/v1/specs/openapi.yaml

echo "==> OpenAPI enum scanner rejects unversioned enum schemas"
openapi_base
cat >> "${OPENAPI_DIR}/openapi.yaml" <<'EOF'
    UserRoleCode:
      type: string
      description: User role code.
      enum: [admin, teamlead, member]
EOF
reject "unversioned enum schema rejected" "${WORK}" "check-openapi-enums: FAIL" bash "${LIB}/check-openapi-enums.sh" backend/application/src/main/resources/api/v1/specs/openapi.yaml


SERVICE_DIR="${WORK}/backend/service/src/main/java/com/example/demo/service/widget"
mkdir -p "${SERVICE_DIR}/services/impl" "${SERVICE_DIR}/services"

echo "==> service quality scanner accepts documented contract and small impl"
cat > "${SERVICE_DIR}/services/WidgetService.java" <<'EOF'
package com.example.demo.service.widget.services;
/**
 * Coordinates widget business operations.
 */
public interface WidgetService {
    /**
     * Finds a widget by id.
     *
     * @param id widget identifier
     * @return matching widget
     */
    String findById(Long id);
}
EOF
cat > "${SERVICE_DIR}/services/impl/WidgetServiceImpl.java" <<'EOF'
package com.example.demo.service.widget.services.impl;
public class WidgetServiceImpl {
    private final String repo;
    public WidgetServiceImpl(String repo) {
        this.repo = repo;
    }
    public String findById(Long id) {
        return repo + id;
    }
}
EOF
accept "documented small service allowed" "${WORK}" bash "${LIB}/check-service-contract-quality.sh" backend/service/src/main/java

echo "==> service quality scanner rejects missing service JavaDoc"
cat > "${SERVICE_DIR}/services/UndocumentedService.java" <<'EOF'
package com.example.demo.service.widget.services;
public interface UndocumentedService {
    String findById(Long id);
}
EOF
reject "undocumented service contract rejected" "${WORK}" "check-service-contract-quality: FAIL" bash "${LIB}/check-service-contract-quality.sh" backend/service/src/main/java
rm -f "${SERVICE_DIR}/services/UndocumentedService.java"

echo "==> service quality scanner rejects private-method piles"
cat > "${SERVICE_DIR}/services/impl/BulkyServiceImpl.java" <<'EOF'
package com.example.demo.service.widget.services.impl;
public class BulkyServiceImpl {
    public String run() { return one(); }
    private String one() { return "1"; }
    private String two() { return "2"; }
    private String three() { return "3"; }
    private String four() { return "4"; }
    private String five() { return "5"; }
    private String six() { return "6"; }
    private String seven() { return "7"; }
    private String eight() { return "8"; }
    private String nine() { return "9"; }
}
EOF
reject "private-method pile rejected" "${WORK}" "check-service-contract-quality: FAIL" bash "${LIB}/check-service-contract-quality.sh" backend/service/src/main/java
rm -f "${SERVICE_DIR}/services/impl/BulkyServiceImpl.java"

DOC_OPENAPI="${WORK}/backend/application/src/main/resources/api/v1/specs/documented-openapi.yaml"
UNDOC_OPENAPI="${WORK}/backend/application/src/main/resources/api/v1/specs/undocumented-openapi.yaml"

echo "==> OpenAPI documentation scanner accepts described contract"
cat > "${DOC_OPENAPI}" <<'EOF'
openapi: 3.0.3
info:
  title: Demo
  version: 1.0.0
paths:
  /api/v1/widgets:
    get:
      operationId: listWidgets
      summary: List widgets.
      description: Returns widgets visible to the caller.
      responses:
        "200":
          description: Visible widgets.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/WidgetListV1"
components:
  schemas:
    WidgetListV1:
      type: object
      additionalProperties: false
      description: List response for widgets.
      properties:
        items:
          type: array
          description: Widgets returned for the current page.
          items:
            $ref: "#/components/schemas/WidgetV1"
    WidgetV1:
      type: object
      additionalProperties: false
      description: Widget visible in the API.
      properties:
        id: { type: integer, format: int64, description: "Widget identifier." }
        name: { type: string, description: "Widget display name." }
EOF
accept "documented OpenAPI allowed" "${WORK}" bash "${LIB}/check-openapi-documentation.sh" backend/application/src/main/resources/api/v1/specs/documented-openapi.yaml

echo "==> OpenAPI documentation scanner rejects missing descriptions"
cat > "${UNDOC_OPENAPI}" <<'EOF'
openapi: 3.0.3
info:
  title: Demo
  version: 1.0.0
paths:
  /api/v1/widgets:
    get:
      operationId: listWidgets
      responses:
        "200":
          description: Visible widgets.
components:
  schemas:
    WidgetV1:
      type: object
      additionalProperties: false
      properties:
        id: { type: integer, format: int64 }
EOF
reject "undocumented OpenAPI rejected" "${WORK}" "check-openapi-documentation: FAIL" bash "${LIB}/check-openapi-documentation.sh" backend/application/src/main/resources/api/v1/specs/undocumented-openapi.yaml

THIN_CONTROLLER_ROOT="${WORK}/thin-controller-project/backend/application/src/main/java/com/example/demo"
mkdir -p "${THIN_CONTROLLER_ROOT}/controllers" "${THIN_CONTROLLER_ROOT}/web"
cat > "${THIN_CONTROLLER_ROOT}/controllers/WidgetController.java" <<'EOF'
package com.example.demo.controllers;
public class WidgetController {
    private final WidgetService service;
    WidgetController(WidgetService service) { this.service = service; }
    Object getWidget(String id) { return service.getWidget(id); }
    org.springframework.http.ResponseEntity<?> wildcardResponse() { return null; }
    interface WidgetService { Object getWidget(String id); }
}
EOF
cat > "${THIN_CONTROLLER_ROOT}/web/SpaFallbackController.java" <<'EOF'
package com.example.demo.web;
public class SpaFallbackController {
    Object route(boolean exists) { if (!exists) { return null; } return new Object(); }
}
EOF
echo "==> thin controller scanner accepts delegation and exempt infrastructure web controller"
accept "delegating API and infrastructure web controller allowed" "${THIN_CONTROLLER_ROOT}" python3 "${LIB}/check-thin-controllers.py" "${THIN_CONTROLLER_ROOT}"

echo "==> thin controller scanner rejects branches, repository access, DTO construction, and try/catch"
cat > "${THIN_CONTROLLER_ROOT}/controllers/WidgetController.java" <<'EOF'
package com.example.demo.controllers;
public class WidgetController {
    private final WidgetRepository widgetRepository;
    Object getWidget(boolean enabled) {
        try {
            if (enabled) { return new WidgetV1(); }
        } catch (RuntimeException ignored) { return null; }
        return widgetRepository.find().stream().findFirst().orElse(enabled ? null : new WidgetV1());
    }
    interface WidgetRepository { Object find(); }
    static final class WidgetV1 {}
}
EOF
reject "business logic in API controller rejected" "${THIN_CONTROLLER_ROOT}" "check-thin-controllers: FAIL" python3 "${LIB}/check-thin-controllers.py" "${THIN_CONTROLLER_ROOT}"

DOC_LINK_ROOT="${WORK}/documentation-link-project"
mkdir -p "${DOC_LINK_ROOT}/.claude/agent_docs"
touch "${DOC_LINK_ROOT}/.claude/agent_docs/present.md"
cat > "${DOC_LINK_ROOT}/CLAUDE.md" <<'EOF'
Read `.claude/agent_docs/present.md` first.
[A local policy](.claude/agent_docs/present.md)
EOF
echo "==> installed documentation link scanner accepts existing project-local docs"
accept "existing installed documentation reference allowed" "${DOC_LINK_ROOT}" python3 "${LIB}/check-installed-documentation-links.py" "${DOC_LINK_ROOT}"
cat > "${DOC_LINK_ROOT}/CLAUDE.md" <<'EOF'
Read `.claude/agent_docs/missing.md` first.
[A missing local policy](.claude/agent_docs/missing.md)
EOF
echo "==> installed documentation link scanner rejects stale project-local docs"
reject "stale installed documentation reference rejected" "${DOC_LINK_ROOT}" "check-installed-documentation-links: FAIL" python3 "${LIB}/check-installed-documentation-links.py" "${DOC_LINK_ROOT}"
cat > "${DOC_LINK_ROOT}/CLAUDE.md" <<'EOF'
Read `custom_instruction/instructions.md` before changing the backend.
EOF
echo "==> installed documentation link scanner rejects removed control-plane docs"
reject "removed control-plane documentation reference rejected" "${DOC_LINK_ROOT}" "check-installed-documentation-links: FAIL" python3 "${LIB}/check-installed-documentation-links.py" "${DOC_LINK_ROOT}"
mkdir -p "${DOC_LINK_ROOT}/frontend"
cat > "${DOC_LINK_ROOT}/CLAUDE.md" <<'EOF'
Read `.claude/agent_docs/present.md` first.
EOF
cat > "${DOC_LINK_ROOT}/frontend/vite.config.ts" <<'EOF'
// See templates/generated-project/frontend/canonical-react-frontend-rules.md.
EOF
echo "==> installed documentation link scanner scans surviving application sources"
reject "control-plane reference in frontend source rejected" "${DOC_LINK_ROOT}" "check-installed-documentation-links: FAIL" python3 "${LIB}/check-installed-documentation-links.py" "${DOC_LINK_ROOT}"

DEPENDENCY_ROOT="${WORK}/dependency-analysis-project/backend"
mkdir -p "${DEPENDENCY_ROOT}"
cat > "${DEPENDENCY_ROOT}/pom.xml" <<'EOF'
<project>
  <build><pluginManagement><plugins><plugin>
    <groupId>org.apache.maven.plugins</groupId><artifactId>maven-dependency-plugin</artifactId>
    <executions><execution><phase>verify</phase><goals><goal>analyze-only</goal></goals>
      <configuration><failOnWarning>true</failOnWarning><ignoreNonCompile>true</ignoreNonCompile></configuration>
    </execution></executions>
  </plugin></plugins></pluginManagement><plugins><plugin>
    <groupId>org.apache.maven.plugins</groupId><artifactId>maven-dependency-plugin</artifactId>
  </plugin></plugins></build>
</project>
EOF
cat > "${DEPENDENCY_ROOT}/DEPENDENCY-ANALYSIS.md" <<'EOF'
No ignores are configured.
EOF
echo "==> Maven dependency analysis scanner accepts a strict plugin configuration"
accept "strict dependency analysis configuration allowed" "${DEPENDENCY_ROOT}" python3 "${LIB}/check-maven-dependency-analysis.py" "${DEPENDENCY_ROOT}"
sed -i.bak 's/<failOnWarning>true<\//<failOnWarning>false<\//g' "${DEPENDENCY_ROOT}/pom.xml"
rm -f "${DEPENDENCY_ROOT}/pom.xml.bak"
echo "==> Maven dependency analysis scanner rejects a weakened plugin configuration"
reject "weakened dependency analysis configuration rejected" "${DEPENDENCY_ROOT}" "failOnWarning=true and ignoreNonCompile=true are required" python3 "${LIB}/check-maven-dependency-analysis.py" "${DEPENDENCY_ROOT}"


STRUCTURE_WORK="${WORK}/structure-lint-mappers"
mkdir -p "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers" \
  "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson" \
  "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/web" \
  "${STRUCTURE_WORK}/backend/service/src/main/java/com/aidigital/demo/service/mappers/lesson"
cat > "${STRUCTURE_WORK}/backend/pom.xml" <<'EOF'
<project>
  <groupId>com.aidigital.demo</groupId>
  <packaging>pom</packaging>
  <modules>
    <module>application</module>
    <module>service</module>
    <module>domain</module>
    <module>migrations</module>
    <module>observability</module>
  </modules>
</project>
EOF
for m in application service domain migrations observability; do
  mkdir -p "${STRUCTURE_WORK}/backend/${m}/src/main/java"
  cat > "${STRUCTURE_WORK}/backend/${m}/pom.xml" <<EOF
<project>
  <artifactId>${m}</artifactId>
  <dependencies><dependency><artifactId>lombok</artifactId></dependency></dependencies>
</project>
EOF
done
cat > "${STRUCTURE_WORK}/backend/service/pom.xml" <<'EOF'
<project>
  <artifactId>service</artifactId>
  <dependencies>
    <dependency><artifactId>lombok</artifactId></dependency>
  </dependencies>
</project>
EOF
cat > "${STRUCTURE_WORK}/backend/application/pom.xml" <<'EOF'
<project>
  <artifactId>application</artifactId>
  <dependencies>
    <dependency><artifactId>lombok</artifactId></dependency>
    <dependency><artifactId>observability</artifactId></dependency>
  </dependencies>
</project>
EOF
mkdir -p \
  "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/config" \
  "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/observability" \
  "${STRUCTURE_WORK}/backend/application/src/main/resources" \
  "${STRUCTURE_WORK}/backend/migrations/src/main/resources/db/changelog" \
  "${STRUCTURE_WORK}/backend/observability/src/main/java/com/aidigital/demo/observability/external"
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/Application.java" <<'EOF'
package com.aidigital.demo;
public class Application {}
EOF
cat > "${STRUCTURE_WORK}/backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml" <<'EOF'
<databaseChangeLog/>
EOF
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/config/LogbookConfig.java" <<'EOF'
package com.aidigital.demo.config;
public class LogbookConfig {}
EOF
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/observability/CorrelationIdFilter.java" <<'EOF'
package com.aidigital.demo.observability;
public class CorrelationIdFilter {}
EOF
cat > "${STRUCTURE_WORK}/backend/observability/src/main/java/com/aidigital/demo/observability/external/ExternalCallTimer.java" <<'EOF'
package com.aidigital.demo.observability.external;
public class ExternalCallTimer {}
EOF
cat > "${STRUCTURE_WORK}/backend/observability/src/main/java/com/aidigital/demo/observability/external/ExternalClientMetricsInterceptor.java" <<'EOF'
package com.aidigital.demo.observability.external;
public class ExternalClientMetricsInterceptor {}
EOF
touch "${STRUCTURE_WORK}/backend/application/src/main/resources/logback-spring.xml"
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/web/SpaFallbackController.java" <<'EOF'
package com.aidigital.demo.web;
public class SpaFallbackController {}
EOF
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson/LessonApiMapper.java" <<'EOF'
package com.aidigital.demo.mappers.lesson;
import org.mapstruct.Mapper;
@Mapper
public interface LessonApiMapper {}
EOF
cat > "${STRUCTURE_WORK}/backend/service/src/main/java/com/aidigital/demo/service/mappers/lesson/LessonMapper.java" <<'EOF'
package com.aidigital.demo.service.mappers.lesson;
import org.mapstruct.Mapper;
@Mapper
public interface LessonMapper {}
EOF

echo "==> structure-lint accepts aggregate-owned MapStruct mappers"
accept "aggregate-owned mappers allowed" "${STRUCTURE_WORK}" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"

echo "==> structure-lint rejects controller generated DTO construction"
mkdir -p "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/controllers"
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/controllers/ManualDtoController.java" <<'EOF'
package com.aidigital.demo.controllers;
public class ManualDtoController {
    Object run() {
        return new OkResponseV1();
    }
    static final class OkResponseV1 {}
}
EOF
reject "controller generated DTO construction rejected" "${STRUCTURE_WORK}" "Controllers must not manually construct generated *V1 DTOs" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"
rm -f "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/controllers/ManualDtoController.java"

echo "==> structure-lint rejects Map object service contracts"
mkdir -p "${STRUCTURE_WORK}/backend/service/src/main/java/com/aidigital/demo/service/lesson/services"
cat > "${STRUCTURE_WORK}/backend/service/src/main/java/com/aidigital/demo/service/lesson/services/LessonRevisionGenerationService.java" <<'EOF'
package com.aidigital.demo.service.lesson.services;
import java.util.Map;
public interface LessonRevisionGenerationService {
    Map<String, Object> generateRevisionBrief(Map<String, Object> prompt);
}
EOF
reject "Map<String,Object> service contract rejected" "${STRUCTURE_WORK}" "Service interfaces must not expose Map<String,Object>" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"
rm -rf "${STRUCTURE_WORK}/backend/service/src/main/java/com/aidigital/demo/service/lesson"

echo "==> structure-lint rejects one-field service ListRecord wrappers"
mkdir -p "${STRUCTURE_WORK}/backend/service/src/main/java/com/aidigital/demo/service/lesson/models"
cat > "${STRUCTURE_WORK}/backend/service/src/main/java/com/aidigital/demo/service/lesson/models/LessonsListRecord.java" <<'EOF'
package com.aidigital.demo.service.lesson.models;
import java.util.List;
public record LessonsListRecord(List<String> lessons) { }
EOF
reject "one-field service ListRecord rejected" "${STRUCTURE_WORK}" "One-field service *ListRecord wrappers are forbidden" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"
rm -rf "${STRUCTURE_WORK}/backend/service/src/main/java/com/aidigital/demo/service/lesson"

echo "==> structure-lint rejects global ApiDtoMapper"
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/ApiDtoMapper.java" <<'EOF'
package com.aidigital.demo.mappers;
public class ApiDtoMapper {}
EOF
reject "global ApiDtoMapper rejected" "${STRUCTURE_WORK}" "Global API mapper is forbidden" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"
rm -f "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/ApiDtoMapper.java"


echo "==> structure-lint rejects aggregate-local mapper package"
mkdir -p "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/lesson/mappers"
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/lesson/mappers/OldLessonApiMapper.java" <<'EOF'
package com.aidigital.demo.lesson.mappers;
import org.mapstruct.Mapper;
@Mapper
public interface OldLessonApiMapper {}
EOF
reject "aggregate-local mapper package rejected" "${STRUCTURE_WORK}" "Application API mapper must live under mappers/<aggregate>/" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"
rm -rf "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/lesson"

echo "==> structure-lint rejects hand-written application mapper class"
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson/ManualMapper.java" <<'EOF'
package com.aidigital.demo.mappers.lesson;
public class ManualMapper {}
EOF
reject "hand-written mapper class rejected" "${STRUCTURE_WORK}" "Application API mapper must live under mappers/<aggregate>/" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"
rm -f "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson/ManualMapper.java"


echo "==> structure-lint rejects manual default Map API mapper"
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson/ManualMapApiMapper.java" <<'EOF'
package com.aidigital.demo.mappers.lesson;
import java.util.Map;
import org.mapstruct.Mapper;
@Mapper
public interface ManualMapApiMapper {
    default Object toDto(Map<String, Object> map) { return new WidgetV1(); }
    final class WidgetV1 {}
}
EOF
reject "manual default Map API mapper rejected" "${STRUCTURE_WORK}" "Application mapper must not hide manual Map<String,Object> mapping in default methods" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"
rm -f "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson/ManualMapApiMapper.java"

echo "==> structure-lint rejects artificial mapper source wrappers"
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson/LessonsListSource.java" <<'EOF'
package com.aidigital.demo.mappers.lesson;
import java.util.List;
public record LessonsListSource(List<String> lessons) { }
EOF
reject "mapper source wrapper rejected" "${STRUCTURE_WORK}" "Application mapper source wrapper records (*ListSource/*ResponseSource) are forbidden" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"
rm -f "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson/LessonsListSource.java"

echo "==> structure-lint rejects creating mapper source wrappers"
cat > "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson/WrapperApiMapper.java" <<'EOF'
package com.aidigital.demo.mappers.lesson;
import org.mapstruct.Mapper;
@Mapper
public interface WrapperApiMapper {
    default Object wrap(java.util.List<String> lessons) {
        return new LessonsListSource(lessons);
    }
}
EOF
reject "mapper-created source wrapper rejected" "${STRUCTURE_WORK}" "Application mapper must not create artificial *Source wrapper records" STRUCTURE_LINT_ALLOW_SAMPLE=1 bash "${SCAFFOLD}/scripts/structure-lint.sh"
rm -f "${STRUCTURE_WORK}/backend/application/src/main/java/com/aidigital/demo/mappers/lesson/WrapperApiMapper.java"

FRONTEND_WORK="${WORK}/frontend-ui"
FRONTEND_SRC="${FRONTEND_WORK}/frontend/src"
RESET_DIR="${FRONTEND_SRC}/shared/ui/base"
DEMO_DIR="${FRONTEND_SRC}/features/demo"
mkdir -p "${RESET_DIR}" "${DEMO_DIR}"

write_good_frontend_reset() {
  cat > "${RESET_DIR}/reset.css" <<'EOF'
body {
    overflow-wrap: anywhere;
}

button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-inline-size: 0;
    max-inline-size: 100%;
    text-align: center;
}
EOF
}

echo "==> frontend UI scanner rejects raw px units"
write_good_frontend_reset
cat > "${DEMO_DIR}/demo.css" <<'EOF'
.demo {
    padding: 12px;
}
EOF
reject "raw px unit rejected" "${FRONTEND_WORK}" "check-frontend-ui-rules: FAIL" bash "${LIB}/check-frontend-ui-rules.sh" frontend/src
rm -f "${DEMO_DIR}/demo.css"

echo "==> frontend UI scanner rejects broken button reset"
cat > "${RESET_DIR}/reset.css" <<'EOF'
body {
    overflow-wrap: anywhere;
}

button {
    display: block;
}
EOF
reject "broken button reset rejected" "${FRONTEND_WORK}" "check-frontend-ui-rules: FAIL" bash "${LIB}/check-frontend-ui-rules.sh" frontend/src

echo "==> frontend UI scanner rejects fixed four-column grids without responsive collapse"
write_good_frontend_reset
cat > "${DEMO_DIR}/demo.css" <<'EOF'
.demo-form {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 0.75rem;
}
EOF
reject "fixed four-column grid rejected" "${FRONTEND_WORK}" "check-frontend-ui-rules: FAIL" bash "${LIB}/check-frontend-ui-rules.sh" frontend/src
rm -f "${DEMO_DIR}/demo.css"

echo "==> frontend UI scanner rejects unvalidated forms"
write_good_frontend_reset
cat > "${DEMO_DIR}/DemoForm.tsx" <<'EOF'
export function DemoForm() {
    return (
        <form>
            <label htmlFor="name">Name</label>
            <input id="name" />
            <button type="submit">Save</button>
        </form>
    );
}
EOF
reject "unvalidated form rejected" "${FRONTEND_WORK}" "check-frontend-ui-rules: FAIL" bash "${LIB}/check-frontend-ui-rules.sh" frontend/src
rm -f "${DEMO_DIR}/DemoForm.tsx"

echo "==> frontend UI scanner accepts validated rem-based form"
cat > "${DEMO_DIR}/demo.css" <<'EOF'
.demo {
    display: grid;
    gap: 0.75rem;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    min-width: 0;
}

@media (max-width: 48rem) {
    .demo {
        grid-template-columns: repeat(2, minmax(0, 1fr));
    }
}
EOF
cat > "${DEMO_DIR}/DemoForm.tsx" <<'EOF'
export function DemoForm() {
    const nameError = "Name is required";
    return (
        <form>
            <label htmlFor="name">Name</label>
            <input
                id="name"
                required
                aria-invalid={Boolean(nameError)}
                aria-describedby="name-error"
            />
            <p id="name-error" role="alert">{nameError}</p>
            <button type="submit">Save</button>
        </form>
    );
}
EOF
accept "validated rem-based form allowed" "${FRONTEND_WORK}" bash "${LIB}/check-frontend-ui-rules.sh" frontend/src
rm -f "${DEMO_DIR}/demo.css" "${DEMO_DIR}/DemoForm.tsx"

echo "==> canonical scaffold passes production scanners"
accept "scaffold passes magic scanner" "${SCAFFOLD}" bash "${LIB}/check-production-magic-values.sh"

accept "scaffold passes static scanner" "${SCAFFOLD}" bash "${LIB}/check-production-static-methods.sh"

accept "scaffold passes current-time scanner" "${SCAFFOLD}" bash "${LIB}/check-production-current-time.sh"

accept "scaffold passes manual-mapping scanner" "${SCAFFOLD}" bash "${LIB}/check-production-manual-mapping.sh"

accept "scaffold passes frontend UI scanner" "${SCAFFOLD}" bash "${LIB}/check-frontend-ui-rules.sh"

gate_summary "test-check-production-scanners"
