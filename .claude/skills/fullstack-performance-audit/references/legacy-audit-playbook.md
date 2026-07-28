---
name: fullstack-performance-audit
description: Repository-wide performance audit of a Spring Boot backend and React frontend with verified findings and an implementation plan
---

Perform a thorough performance audit of the entire repository for: **$ARGUMENTS**

## Arguments

Arguments are optional and provide additional application or performance context.

Use the following format:

```text
<application context> [| focus: <area or workflow>] [| symptoms: <known problems>] [| requirements: <performance targets>] [| evidence: <metrics, traces, reports, or file paths>] [| stack: <technology context>]
```

Examples:

```text
Operational platform used by internal users. Main workflows are dashboard loading, campaign editing, reporting, and file export.
```

```text
Catalog service processing high-volume product updates. | symptoms: RPS stops scaling after 130 and response time grows above 10 seconds | requirements: p95 below 2 seconds at 200 RPS
```

```text
Full application audit | focus: dashboard loading and report generation | evidence: load-tests/results.jtl, frontend/stats.html | stack: Java 21, Spring Boot 3, PostgreSQL, React, TanStack Query
```

Parse optional sections by their prefixes:

* `focus:` — workflows or application areas that deserve additional attention
* `symptoms:` — known latency, throughput, CPU, memory, rendering, or stability problems
* `requirements:` — expected RPS, concurrency, latency, data volume, Core Web Vitals, resource limits, or other targets
* `evidence:` — paths to load-test results, profiler output, traces, metrics, browser recordings, query plans, or reports
* `stack:` — optional stack details not easily discoverable from the repository
* text before the first prefixed section — optional general application context

The audit scope is always the **entire repository**.

A supplied focus area, symptom, ticket, file, commit, or performance report must not restrict the audit only to that area. Use it to prioritize investigation while still reviewing the complete application.

Do not modify production code unless the user explicitly requests fixes. The primary output of this skill is a verified performance report and an implementation plan.

# Audit objective

Act as a senior performance engineer reviewing a production application consisting of a Spring Boot backend and React frontend.

Analyze the repository as one end-to-end system:

```text
Browser interaction
    → React rendering and state changes
    → frontend data-fetching layer
    → network request
    → Spring Boot controller
    → service and transaction boundaries
    → repository or external client
    → database, cache, message broker, or external service
    → response serialization
    → frontend cache update and rendering
```

Identify verified performance problems that affect or may realistically affect:

* response latency
* throughput
* scalability
* CPU usage
* memory usage and garbage collection
* database load
* connection-pool usage
* external-service capacity
* frontend rendering
* browser memory
* network traffic
* bundle loading
* resource exhaustion
* stability under concurrency
* infrastructure cost

Do not produce a generic list of performance best practices.

Prefer a small number of well-supported, high-impact findings over a large number of speculative optimizations.

# Core scope rule

This is a repository-wide audit.

Always inspect the complete relevant application structure, including:

* all backend modules
* all frontend applications and packages
* shared libraries used on production paths
* database schemas and migrations
* persistence mappings and repositories
* REST, GraphQL, WebSocket, and messaging interfaces
* external-service clients
* caches
* schedulers and background jobs
* batch-processing flows
* application configuration
* deployment and infrastructure configuration
* build configuration
* tests
* observability configuration
* load-testing and profiling assets

Do not select the review scope using:

* the latest commit
* local working-tree changes
* a pull request diff
* explicitly supplied commits
* a single ticket
* one known slow endpoint

Git history and diffs may be inspected to understand why a problem exists or when it was introduced, but they do not define the audit boundary.

If the repository is too large to inspect every implementation in equal depth:

1. inventory all modules and production entry points;
2. identify performance-critical paths;
3. deeply inspect those paths;
4. perform a lighter structural scan of the remaining modules;
5. clearly list any areas that could not be fully verified.

Do not silently claim full coverage when parts of the repository were not inspected.

# Step 1 — Establish repository structure

Start by identifying:

* backend modules
* frontend modules
* deployable applications
* shared packages
* databases and persistence technologies
* message brokers
* cache technologies
* external integrations
* scheduled jobs
* batch processes
* reporting and export processes
* build tools
* deployment model

Inspect repository files such as:

```text
pom.xml
build.gradle
settings.gradle
package.json
package-lock.json
yarn.lock
pnpm-lock.yaml
vite.config.*
webpack.config.*
tsconfig.json
application.yml
application.properties
Dockerfile
docker-compose.yml
helm/*
k8s/*
terraform/*
liquibase/*
flyway/*
README.md
CLAUDE.md
AGENTS.md
CONTRIBUTING.md
```

Read repository-local development and architectural rules.

Apply the idioms and runtime semantics of the actual framework and library versions found in the repository.

Do not assume framework versions from general stack names.

# Step 2 — Build the application performance model

Before reporting findings, establish how the application performs work.

Identify:

* main user-facing workflows
* most frequently used pages and endpoints
* read-heavy and write-heavy paths
* background and scheduled workflows
* high-volume entities
* large tables and collections
* data exports and reports
* file and media processing
* external-service dependencies
* caching boundaries
* synchronous and asynchronous boundaries
* transaction boundaries
* request retry behaviour
* frontend cache and invalidation behaviour

For each important workflow, trace the complete execution path.

Example:

```text
DashboardPage
    → useDashboardQuery()
    → GET /api/dashboard
    → DashboardController.getDashboard()
    → DashboardService.loadDashboard()
    → CampaignRepository.findActive()
    → ReportRepository.findLatestByCampaignIds()
    → PostgreSQL
    → DashboardResponse
    → TanStack Query cache
    → Dashboard widgets
```

Do not assess isolated methods without examining their callers, expected invocation frequency, input cardinality, and downstream operations.

# Step 3 — Establish workload assumptions

Use supplied requirements when available.

Otherwise, derive available workload information from:

* documentation
* load-test scripts
* pagination defaults
* configured batch sizes
* deployment replica counts
* CPU and memory limits
* database pool sizes
* scheduler frequencies
* event-consumer concurrency
* sample datasets
* production-oriented tests
* metrics and dashboards stored in the repository

Identify, where possible:

* expected RPS
* concurrent users
* expected event rate
* database size
* common and maximum result-set sizes
* maximum upload and export sizes
* frontend table sizes
* required p50, p95, and p99 latency
* background-job completion requirements
* CPU and memory constraints
* downstream rate limits

When workload information is unavailable, do not invent exact traffic or data volumes.

Instead:

* state the missing assumption;
* explain which conclusion depends on it;
* classify the concern as requiring measurement when necessary;
* provide a concrete verification procedure.

# Step 4 — Inspect available runtime evidence

Look for and inspect:

* JMeter results
* Gatling reports
* k6 results
* Locust results
* Java Flight Recorder output
* async-profiler output
* heap dumps
* thread dumps
* Micrometer metrics
* Spring Actuator configuration
* OpenTelemetry traces
* database execution plans
* slow-query logs
* HikariCP metrics
* browser performance recordings
* React Profiler output
* Lighthouse reports
* Web Vitals measurements
* frontend bundle reports
* production logs
* monitoring queries and dashboards

Do not claim runtime behaviour was verified when only static code was inspected.

Clearly distinguish:

* verified from code;
* verified from runtime evidence;
* strongly indicated by code but requiring measurement;
* not assessable due to missing evidence.

# Part 1 — Spring Boot backend audit

## 1. Request processing

Check for:

* expensive work on request threads
* blocking calls on constrained executors
* accidental serialization of independent operations
* long synchronous call chains
* request fan-out
* remote calls inside loops
* repeated authentication or metadata lookup
* repeated parsing or validation
* unnecessary object conversions
* duplicate work within one request
* lack of request-level deduplication
* request timeouts longer than downstream timeouts
* missing cancellation or interruption handling
* response construction that materializes excessive data

Trace findings from the controller or consumer entry point to the final dependency.

## 2. Threading and concurrency

Check for:

* unmanaged thread creation
* `parallelStream()` on production request paths
* use of the shared common fork-join pool
* unbounded executors
* unbounded work queues
* incorrectly sized thread pools
* thread-pool starvation
* blocking work on reactive or event-loop threads
* broad synchronized blocks
* lock contention
* check-then-act races causing duplicate work
* transactions held while waiting for external services
* concurrency exceeding downstream capacity
* scheduler overlap
* duplicate scheduled-job execution across replicas
* unsafe use of `@Async`
* missing exception propagation from asynchronous execution
* incorrect virtual-thread assumptions

Do not recommend more threads without checking CPU, connection pools, database capacity, and downstream limits.

## 3. Transactions

Check for:

* transactions spanning remote calls
* transactions spanning long calculations
* excessive transaction scope
* one transaction per item in large loops
* one transaction around an excessively large batch
* unnecessary write transactions
* repeated flushes
* explicit flushes on hot paths
* lock-heavy update patterns
* inappropriate isolation levels
* retry logic around non-idempotent transactions
* lazy loading outside the intended transaction boundary
* database connections retained during non-database work

## 4. Database access

Inspect repositories, ORM mappings, queries, migrations, and callers together.

Check for:

* N+1 queries
* repeated equivalent queries in one workflow
* excessive query count per request
* fetching entities when projections are sufficient
* unbounded repository methods
* missing pagination
* unsafe maximum page sizes
* large offset pagination
* expensive count queries
* fetching all rows before filtering
* filtering, sorting, joining, or grouping in Java
* eager-loading explosions
* unnecessary fetch joins
* Cartesian products
* multiple bag-fetch problems
* lazy loading during mapping or serialization
* one-row-at-a-time inserts or updates
* ineffective JDBC batching
* excessive batch size
* large `IN` predicates
* full scans
* non-sargable predicates
* predicates inconsistent with index order
* sorts not supported by indexes
* function application to indexed columns
* missing indexes verified against migrations
* redundant or write-expensive indexes
* hot rows
* lock contention
* connection-pool exhaustion
* database work performed after obtaining more rows than needed
* read-modify-write flows that could be atomic
* retry amplification
* non-idempotent writes

Do not report a missing index based only on a query.

Before recommending an index:

1. inspect existing migrations and schema definitions;
2. inspect column cardinality and query shape where evidence exists;
3. consider write overhead;
4. provide the query requiring verification;
5. request or inspect an execution plan.

## 5. JPA and Hibernate

Check specifically for:

* incorrect fetch type on frequently loaded entities
* bidirectional relationships loading excessive graphs
* entity serialization
* implicit dirty checking of large persistence contexts
* excessive persistence-context growth
* missing `clear()` during large batch processing
* incorrect batching configuration
* identity generation disabling batching
* unnecessary entity loading before update or delete
* repository methods returning complete graphs
* pagination with collection fetch joins
* expensive cascade operations
* orphan removal on large collections
* `save()` calls inside loops
* excessive mapper-triggered lazy loading
* repeated `findById()` for already available entities
* count and content queries duplicating expensive joins

## 6. Memory and allocation

Check for:

* unbounded collection materialization
* reading full database results into memory
* reading complete files into byte arrays
* large in-memory exports
* repeated collection copies
* multiple stream passes over large datasets
* nested grouping
* repeated sorting
* large temporary maps
* unnecessary DTO chains
* repeated JSON serialization
* repeated deserialization
* string concatenation or regex compilation on hot paths
* unbounded caches
* retention of request data
* static collections that grow indefinitely
* excessively large logging payloads
* high allocation rates in frequently executed mappers

Explain cardinality and complexity when they can be established.

Example:

```text
O(customers × campaigns)
```

Do not describe small collection processing as a production issue without evidence that the collection can become large or the path is frequently executed.

## 7. Caching

Check for:

* repeated expensive reads suitable for caching
* caching of cheap operations
* incorrect cache keys
* keys missing tenant, locale, version, or permission context
* unbounded local caches
* missing TTL
* excessively long TTL
* cache stampedes
* no negative caching where repeated misses are expensive
* stale-data correctness problems
* inconsistent invalidation
* invalidation of an entire cache for one-record changes
* caching mutable values
* caching very large results
* Spring self-invocation bypassing cache proxies
* methods not intercepted due to visibility or proxy configuration
* duplicate caching at multiple layers
* per-instance caches producing inconsistent behaviour
* cache configuration incompatible with horizontal scaling

Do not recommend caching without describing:

* cache key;
* expected reuse;
* invalidation;
* TTL;
* maximum size;
* consistency requirements;
* expected benefit.

## 8. External services and HTTP clients

Check for:

* new HTTP client construction per request
* missing connection pooling
* missing keep-alive
* missing connect, read, write, and call timeouts
* excessive timeouts
* retries without backoff
* retries without jitter
* retrying non-idempotent operations
* layered retries multiplying attempts
* remote calls inside loops
* sequential independent calls
* no bulk API usage
* duplicate token acquisition
* duplicate metadata requests
* large request or response payloads
* fetching unused fields
* chatty service integration
* polling with no backoff
* external calls inside database transactions
* missing concurrency limits
* missing circuit breaking where failure amplification is realistic

## 9. Messaging and event processing

Check for:

* per-message database or remote calls
* consumer concurrency incompatible with partition count
* concurrency exceeding database capacity
* large messages
* repeated serialization
* missing backpressure
* unbounded internal queues
* retry storms
* poison-message loops
* inefficient dead-letter handling
* non-idempotent consumers
* duplicate processing
* ordering violations
* excessively broad transactions
* one transaction per tiny operation
* large cross-partition batches
* acknowledgment before durable processing
* slow consumers causing growing lag
* excessive logging per message

## 10. Scheduled jobs and batch processing

Check for:

* full-table scans on every execution
* repeatedly searching all historical records
* no checkpoint or cursor
* missing pagination
* loading all work items
* unstable offset pagination on mutable data
* per-item repository calls
* per-item remote calls
* overlapping job executions
* multiple replicas executing the same job
* no distributed lock where one is required
* oversized transactions
* no restartability
* duplicate processing after restart
* fixed batch sizes with no operational justification
* no cleanup of completed job data
* jobs holding connections while processing non-database work
* no metrics for duration, lag, throughput, and failures

## 11. Serialization and API payloads

Check for:

* oversized responses
* deeply nested response graphs
* repeated fields
* entity exposure
* serializing fields unused by the frontend
* lazy-loading during serialization
* multiple conversion layers
* unnecessary `Map<String, Object>` structures
* inefficient polymorphic deserialization
* large lists without pagination
* missing response compression where payload size justifies it
* compression enabled for tiny responses at excessive CPU cost
* frontend API design requiring many requests for one screen

# Part 2 — React frontend audit

## 1. API usage

Check for:

* duplicate requests
* request waterfalls
* independent requests executed sequentially
* requests triggered on every render
* unstable query keys
* query keys containing newly created objects
* multiple components requesting equivalent data
* incorrect stale times
* aggressive refetching
* refetch on every mount
* unnecessary refetch after mutation
* broad cache invalidation
* polling with no clear need
* polling while the tab is hidden
* polling intervals shorter than data volatility requires
* requests on every keystroke
* missing debounce
* missing request cancellation
* stale requests overwriting newer results
* lack of pagination
* overfetching
* under-aggregated APIs
* downloading full datasets for client-side processing
* duplicate retries in frontend and backend
* duplicate write requests
* missing mutation idempotency

Apply the semantics of the data-fetching library actually used by the repository, such as:

* TanStack Query
* SWR
* Apollo Client
* RTK Query
* custom hooks

## 2. Component rendering

Check for:

* unnecessary rerenders of expensive subtrees
* broad context subscriptions
* whole-store subscriptions
* selectors returning new references
* unstable object props
* unstable array props
* unstable function props where memoized children depend on identity
* expensive calculations during render
* filtering and sorting on every render
* duplicate derived state
* effect-driven derived state
* cascading state updates
* effects causing render loops
* excessively large components
* global state used for local UI state
* expensive hidden components remaining mounted
* rerendering all form fields on one field change

Do not report every missing `useMemo`, `useCallback`, or `React.memo`.

Only report memoization-related findings when:

* the rendered subtree or calculation is meaningfully expensive;
* the operation happens frequently;
* referential instability defeats an existing optimization;
* profiler evidence confirms the impact;
* or the scale of rendered data makes the impact clear.

## 3. Lists, tables, and grids

Check for:

* large datasets rendered without virtualization
* excessive DOM node count
* unstable row keys
* index-based keys causing remounting
* rebuilding columns on every render
* all rows rerendering after one-row updates
* client-side pagination over a full server dataset
* client-side sorting or filtering of excessively large datasets
* expensive cell components
* unnecessary controlled state
* hidden columns still performing expensive work
* excessive formatting per cell
* synchronous export preparation in the browser

## 4. Forms

Check for:

* entire form rerendering on every keystroke
* expensive validation on every change
* remote validation without debounce
* duplicate local and remote validation
* large controlled forms
* excessive watchers or subscriptions
* calculations repeated for all fields
* dependent requests triggered too frequently
* file processing performed synchronously on the main thread

## 5. State management

Check for:

* server state copied into client stores
* duplicated sources of truth
* broad Zustand, Redux, Context, or custom-store subscriptions
* state selectors with unstable results
* large immutable copies
* unnecessary persistence of large state
* stale state retained after navigation
* global stores growing indefinitely
* unrelated components reacting to the same update
* mutation of shared objects defeating change detection
* query cache and global store invalidated independently

## 6. Bundle and loading performance

Inspect build configuration and imports.

Check for:

* large initial JavaScript bundles
* missing route-level code splitting
* heavy components imported eagerly
* whole-library imports
* full icon-library imports
* duplicate dependencies
* ineffective tree shaking
* CommonJS packages preventing optimization
* editors, PDF libraries, charts, maps, or media tools loaded on initial startup
* large source maps deployed publicly
* oversized images
* missing responsive image variants
* missing lazy loading
* excessive fonts or font variants
* render-blocking assets
* incorrect cache headers
* missing asset hashing
* unnecessary polyfills
* development tooling included in production

Do not claim exact bundle impact without a bundle report.

When no report exists, provide the exact project-compatible command needed to generate one.

## 7. Browser CPU and memory

Check for:

* timers not cleaned up
* event listeners not removed
* observers not disconnected
* subscriptions not disposed
* WebSocket or EventSource connections leaked
* object URLs not revoked
* unresolved requests retained
* large closures retained after navigation
* caches growing indefinitely
* detached DOM nodes
* repeated layout measurement
* forced synchronous layouts
* layout thrashing
* unthrottled scroll, drag, resize, or mouse-move handlers
* expensive synchronous work on the main thread
* large JSON parsing
* CPU-heavy transformations that should use a worker or backend processing

## 8. User-perceived performance

Assess verified or measurable impact on:

* initial page load
* route transitions
* time to usable UI
* Largest Contentful Paint
* Interaction to Next Paint
* Cumulative Layout Shift
* typing responsiveness
* table responsiveness
* loading-state stability
* mutation responsiveness
* repeated spinner states
* unnecessary visual blocking
* excessive layout shifts after data loading

Do not claim exact Core Web Vitals without runtime measurements.

# Part 3 — Cross-layer performance

Prioritize problems that span frontend and backend.

Check for:

* one page causing many backend requests
* one backend request causing many database queries
* frontend polling causing continuous database load
* broad frontend invalidation causing request storms
* backend APIs forcing frontend request waterfalls
* frontend downloading data only to discard most of it
* client-side pagination over an unbounded backend response
* large backend responses causing network, parsing, memory, and rendering cost
* repeated retries at browser, gateway, backend, client, and database layers
* duplicate user actions producing duplicate writes
* missing idempotency
* response shapes requiring expensive frontend normalization
* backend concurrency exceeding database pool capacity
* application replica count multiplying configured connection pools
* background jobs competing with interactive requests
* synchronous exports blocking both backend and browser resources
* cache lifetimes inconsistent across frontend and backend

For each cross-layer finding, show the complete amplification path.

Example:

```text
Opening DashboardPage
    → 6 React queries
    → 6 HTTP requests
    → 18 repository calls
    → 42 SQL statements
    → repeated rendering of 2,000 table rows
```

Use exact counts only when verified.

Otherwise write:

```text
SQL query count requires instrumentation.
```

# Part 4 — Configuration and infrastructure

## Spring Boot configuration

Inspect:

* servlet or reactive server thread configuration
* virtual-thread configuration
* HikariCP pool size
* Hikari acquisition timeout
* Hibernate fetch and batch settings
* async executors
* scheduler pools
* HTTP client pools
* cache configuration
* response compression
* multipart limits
* logging levels
* metrics configuration
* tracing sampling
* graceful shutdown
* JVM options
* heap limits
* garbage collector configuration

## Frontend configuration

Inspect:

* production build mode
* source maps
* minification
* tree shaking
* chunking
* code splitting
* asset hashing
* image handling
* proxy settings
* compression
* cache headers
* service-worker behaviour
* environment variables affecting production behaviour

## Deployment configuration

Inspect, when available:

* CPU requests and limits
* memory requests and limits
* replica counts
* autoscaling configuration
* ingress timeouts
* proxy buffering
* keep-alive settings
* readiness probes
* liveness probes
* startup probes
* graceful termination
* database connection limits
* total pool size across replicas
* cache limits
* message-consumer concurrency
* scheduler duplication across replicas

Do not recommend increasing concurrency, replica count, thread pools, or connection pools without assessing the resulting pressure on downstream systems.

# Part 5 — Observability

Assess whether the current system can diagnose performance problems.

Check for:

* endpoint latency metrics
* p50, p95, and p99 latency
* request throughput
* active request count
* queueing time
* Hikari active, idle, pending, and timeout metrics
* query duration
* external-service latency
* retry count
* circuit-breaker state
* scheduler duration
* scheduler lag
* event-consumer lag
* batch throughput
* cache hit and miss ratio
* cache size
* JVM CPU
* heap usage
* allocation rate
* GC pauses
* thread-pool queue size
* browser Web Vitals
* frontend error and request timing
* metrics tag cardinality

Check for observability overhead:

* request IDs or user IDs used as metric tags
* unbounded URI tags
* full payload logging
* large collections logged
* expensive logging inside loops
* synchronous high-volume logging
* stack traces for expected failures
* excessive trace sampling

Missing observability is a finding only when it materially prevents verification or operation of an important workflow.

# Part 6 — Tests and verification

Inspect existing:

* load tests
* integration tests
* repository tests
* concurrency tests
* frontend performance tests
* browser tests
* large-data tests
* benchmark tests

Check for missing coverage of:

* query counts
* maximum page size
* large result sets
* batch boundaries
* concurrent requests
* duplicate requests
* retries
* idempotency
* cache hits
* cache invalidation
* scheduler overlap
* consumer concurrency
* frontend request deduplication
* obsolete request cancellation
* large list rendering
* memory cleanup after navigation
* timeout behaviour
* degraded external services

Run safe verification commands where practical, such as:

* backend compilation
* unit tests
* repository integration tests
* frontend type checking
* frontend production build
* linting
* bundle analysis
* targeted load tests
* static analysis

Do not run destructive commands or uncontrolled load tests against shared or production systems.

Do not claim that a command passed unless it actually completed successfully.

# Verification rules

Before reporting a performance finding:

1. Read the complete affected implementation.
2. Identify the entry point.
3. Inspect callers and consumers.
4. Inspect downstream dependencies.
5. Establish expected invocation frequency or data cardinality where possible.
6. Inspect related configuration.
7. Inspect relevant tests.
8. Check whether caching, batching, framework behaviour, or database constraints already address the concern.
9. Identify the exact file, symbol, and line range.
10. Determine whether the issue is statically verified or requires runtime measurement.

Do not report:

* isolated micro-optimizations
* generic framework recommendations
* every missing cache
* every missing index
* every missing `useMemo`
* every use of streams
* every synchronous method
* every large class
* every additional HTTP request
* every repeated mapping step

Only report them when their actual execution context makes them materially relevant.

# Finding classification

Every finding must use one of these statuses.

## Verified issue

The problematic behaviour is confirmed by code, configuration, schema, tests, build output, profiler output, metrics, traces, or execution plans.

## Requires measurement

The code creates a credible performance risk, but production impact depends on workload, cardinality, frequency, or runtime behaviour not available in the repository.

State exactly what must be measured.

## Observability gap

The application lacks the metrics, traces, logs, or profiling hooks needed to verify or operate a performance-critical path.

Do not present `Requires measurement` findings as confirmed defects.

# Severity definitions

## Critical

A verified problem likely to cause:

* application-wide outage
* uncontrolled resource exhaustion
* database overload
* cascading failure
* severe memory leak
* inability to process the expected normal workload

## High

A verified problem likely to:

* prevent a critical workflow from meeting expected load or latency
* exhaust a shared resource under realistic load
* cause severe request or query amplification
* make the system unstable as normal data volume grows
* significantly degrade all users of an important workflow

## Medium

A verified problem that:

* creates measurable degradation
* materially increases infrastructure cost
* limits scalability of a narrower workflow
* becomes important at a realistic future data volume
* increases operational risk

## Low

A verified localized issue with limited current impact.

`Requires measurement` findings should normally not be marked Critical unless runtime evidence already demonstrates severe impact.

# Finding format

For every finding, use:

```md
### [High] Dashboard loading performs repeated campaign queries

**Status:** Verified issue  
**Layer:** React → HTTP → Spring Boot → PostgreSQL  
**Affected flow:** Opening the campaign dashboard  
**Affected code:**
- `frontend/src/pages/DashboardPage.tsx`, `DashboardPage`, lines 40-86
- `backend/src/main/java/.../DashboardService.java`, `loadDashboard`, lines 72-119
- `backend/src/main/java/.../CampaignRepository.java`, lines 25-48

**Problem**

Explain the complete verified behaviour and concrete impact.

**Evidence**

Describe the inspected execution path, query calls, configuration, tests, metrics, traces, or profiler output.

**Trigger**

Explain the request pattern, concurrency, or data volume required to expose the issue.

**Root cause**

Explain why the implementation creates the problem.

**Fix**

Provide a concrete implementation change.

**Validation**

Describe the measurement, test, query plan, profiler, or metric needed to verify the fix.

**Expected benefit**

Describe the expected reduction in requests, queries, allocations, latency, or resource use without inventing unsupported exact numbers.

**Effort:** Small / Medium / Large  
**Regression risk:** Low / Medium / High
```

Consolidate findings with the same root cause.

Do not create separate findings for every affected component when they are all symptoms of one request-amplification problem.

# Repository coverage tracking

Include a coverage section showing which parts of the repository were inspected.

Use a structure such as:

```md
## Repository Coverage

### Deeply inspected
- Backend API and service layer
- Persistence layer and migrations
- React pages and data-fetching hooks
- Reporting workflow
- Deployment configuration

### Structurally scanned
- Administrative frontend
- Development tooling
- Test utilities

### Not fully verified
- Legacy integration module: external dependency unavailable
- Production database plans: no plans or statistics supplied
```

Do not omit unreviewed areas.

# Final report

Write the report in this structure:

````md
# Full-Stack Performance Audit

## Audit Context
- Repository:
- Application context:
- Supplied focus:
- Known symptoms:
- Performance requirements:
- Stack:
- Runtime evidence available:
- Important workload assumptions:

## Repository Coverage

### Deeply inspected
- ...

### Structurally scanned
- ...

### Not fully verified
- ...

## Executive Assessment
- Production performance verdict
- Primary bottleneck candidates
- Main scalability limit
- Most important missing evidence
- Whether the stated performance requirements are likely to be met

## Critical Findings

### [Critical] Finding
...

OR:

No Critical findings verified.

## High Findings

### [High] Finding
...

OR:

No High findings verified.

## Medium Findings

### [Medium] Finding
...

OR:

No Medium findings verified.

## Low Findings

### [Low] Finding
...

OR:

No Low findings verified.

## Findings Requiring Measurement

### Finding
- suspected behaviour
- existing evidence
- missing evidence
- exact measurement procedure
- pass/fail criteria

OR:

No additional risks requiring measurement identified.

## Cross-Layer Amplification Map

```text
User action
    → frontend operations
    → HTTP requests
    → backend calls
    → database queries
    → external calls
    → frontend renders
````

Use only verified counts.

## Observability Gaps

* ...

OR:

No material observability gaps verified.

## Verified Non-Issues

* Optional findings that were explicitly checked and found acceptable

## Recommended Implementation Plan

### Phase 0 — Measurement baseline

1. ...
2. ...

### Phase 1 — Highest-impact fixes

1. ...
2. ...

### Phase 2 — Structural improvements

1. ...
2. ...

### Phase 3 — Optional optimizations

1. ...
2. ...

For every implementation step include:

* objective
* affected files
* concrete changes
* dependencies
* tests
* runtime validation
* expected benefit
* regression risk
* rollback strategy where relevant

## Validation Plan

### Backend scenarios

* ...

### Frontend scenarios

* ...

### Data volumes

* ...

### Concurrency and load

* ...

### Metrics to collect

* ...

### Baseline

* ...

### Target

* ...

### Pass/fail criteria

* ...

## Verification Performed

* files and modules inspected
* commands executed
* tests executed
* reports inspected
* limitations

## Performance Verdict

**Verdict:** READY / READY WITH PERFORMANCE RISKS / NOT READY

**Must be fixed before production:**

1. ...
2. ...

**Top priorities:**

1. ...
2. ...
3. ...

```

# Verdict rules

## READY

Use only when:

- no Critical or High performance issues were verified;
- no material scalability limit was found for the stated workload;
- sufficient runtime evidence exists for critical workflows.

## READY WITH PERFORMANCE RISKS

Use when:

- no verified blocking issue exists;
- one or more Medium issues or credible measurement-dependent risks remain;
- the application may be acceptable, but additional validation or improvements are needed.

## NOT READY

Use when:

- one or more Critical or High issues remain;
- the application demonstrably cannot meet stated performance requirements;
- an important workflow has an uncontrolled resource-exhaustion risk.

# Final rules

- Audit the repository as a complete system.
- Do not limit the audit to current changes.
- Do not use Git diff as the primary review scope.
- Report only verified findings or explicitly marked measurement-dependent risks.
- Trace findings through real execution paths.
- Include frontend, backend, database, external integrations, configuration, and infrastructure.
- Do not give generic praise.
- Do not summarize application functionality unless needed to explain a finding.
- Do not inflate severity.
- Do not recommend caching, indexing, batching, memoization, parallelism, or larger pools without case-specific evidence.
- Do not modify production files unless explicitly requested.
- Prefer high-impact architectural and I/O problems over micro-optimizations.
- Explicitly disclose incomplete repository coverage.
```
