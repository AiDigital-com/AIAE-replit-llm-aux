#!/usr/bin/env bash
# Creates backend/external-services/ Maven module in a generated project.
# Idempotent — safe to run multiple times.
#
# Usage: install-external-services-module.sh <project-root>
#
# <project-root>  Absolute path to the generated project root (contains backend/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_ROOT="${1:?Usage: install-external-services-module.sh <project-root>}"
BACKEND_DIR="${PROJECT_ROOT}/backend"
EXT_DIR="${BACKEND_DIR}/external-services"
BACKEND_POM="${BACKEND_DIR}/pom.xml"
export BACKEND_POM

if [ ! -f "$BACKEND_POM" ]; then
    echo "[install-external-services-module] ERROR: $BACKEND_POM not found" >&2
    echo "  Make sure the project has been materialized before running pack installers." >&2
    exit 1
fi

# ── Create module directory structure ────────────────────────────────────────
if [ ! -d "$EXT_DIR" ]; then
    echo "[install-external-services-module] Creating external-services module…"
    mkdir -p "${EXT_DIR}/src/main/java"
    mkdir -p "${EXT_DIR}/src/test/java"
else
    echo "[install-external-services-module] external-services directory already exists — skipping mkdir"
fi

# ── Write pom.xml if absent ──────────────────────────────────────────────────
EXT_POM="${EXT_DIR}/pom.xml"
if [ ! -f "$EXT_POM" ]; then
    # Detect groupId from backend/pom.xml to carry it into child pom.
    GROUP_ID=$(python3 - << 'PYEOF'
import sys, xml.etree.ElementTree as ET, os
NS = 'http://maven.apache.org/POM/4.0.0'
tree = ET.parse(os.environ['BACKEND_POM'])
el = tree.getroot().find(f'{{{NS}}}groupId')
print(el.text.strip() if el is not None and el.text else 'PACKAGE_REPLACE_ME')
PYEOF
)
    cat > "$EXT_POM" << POMEOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             https://maven.apache.org/xsd/maven-4.0.0.xsd">

    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>${GROUP_ID}</groupId>
        <artifactId>app-parent</artifactId>
        <version>0.0.1-SNAPSHOT</version>
        <relativePath>../pom.xml</relativePath>
    </parent>

    <!-- Opt-in external-services module. Created by pack installers only.
         Do NOT add dependencies on application, service, domain, or db here.
         Pack installers add their own dependencies below this comment. -->
    <artifactId>external-services</artifactId>
    <name>external-services</name>

    <dependencies>

        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
        </dependency>
        <dependency>
            <groupId>\${project.groupId}</groupId>
            <artifactId>observability</artifactId>
        </dependency>

        <!-- Runtime implementations used through configuration/autoconfiguration.
             Compile APIs are added explicitly by the HTTP foundation installer. -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.zalando</groupId>
            <artifactId>logbook-spring-boot-starter</artifactId>
            <scope>runtime</scope>
        </dependency>

        <!-- Direct test APIs. Keep these explicit so strict dependency analysis
             does not depend on a starter's transitive dependency graph. -->
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter-api</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter-engine</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.mockito</groupId>
            <artifactId>mockito-core</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.mockito</groupId>
            <artifactId>mockito-junit-jupiter</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.assertj</groupId>
            <artifactId>assertj-core</artifactId>
            <scope>test</scope>
        </dependency>

    </dependencies>

</project>
POMEOF
    echo "[install-external-services-module] Created $EXT_POM"
else
    echo "[install-external-services-module] $EXT_POM already exists — skipping creation"
fi

# ── Add <module>external-services</module> to backend/pom.xml ────────────────
bash "${SCRIPT_DIR}/add-maven-module.sh" "$BACKEND_POM" "external-services"

# ── Add external-services to <dependencyManagement> in backend/pom.xml ───────
# Detect version from parent pom.
PARENT_VERSION=$(python3 - << 'PYEOF'
import sys, xml.etree.ElementTree as ET, os
NS = 'http://maven.apache.org/POM/4.0.0'
tree = ET.parse(os.environ['BACKEND_POM'])
el = tree.getroot().find(f'{{{NS}}}version')
print(el.text.strip() if el is not None and el.text else '0.0.1-SNAPSHOT')
PYEOF
)

bash "${SCRIPT_DIR}/add-managed-dependency.sh" \
    "$BACKEND_POM" \
    "\${project.groupId}" \
    "external-services" \
    "\${project.version}"

echo "[install-external-services-module] external-services module ready"
