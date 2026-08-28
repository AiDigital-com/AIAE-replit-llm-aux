# End-to-End AIAE Application Onboarding

Use this runbook after reading the platform context, lessons learned, and
application intake references.

## Phase 0: Select scope and stop conditions

State whether the run is:

- read-only planning;
- DEV onboarding;
- PROD preparation;
- PROD release;
- recovery/rollback.

Record these mandatory stops:

- missing or unapproved credential from 1Password;
- AWS account mismatch;
- dirty checkout that overlaps required files;
- unknown database ownership or migration mechanism;
- Terraform plan with unexplained delete/replace actions;
- missing secret keys;
- failed local build/chart/Terraform validation;
- failed DEV migration, rollout, or smoke test;
- pending CodeConnections or ACM validation;
- absent explicit PROD confirmation.

When a request spans multiple modes, write the ordered mode sequence and the
mutation boundary for each. Example: `onboard-dev` may include a confirmed DEV
apply; `prepare-prod` produces reviewed PROD plans/configuration and stops before
PROD apply; `release-prod` requires its own explicit confirmation.

## Phase 1: Authenticate with existing credentials

### 1.1 1Password

The existing team vault is the source for:

- AWS login/CLI access material or Identity Center profile details;
- the approved GitHub/GitOps token;
- any other credential the user has explicitly stored for this deployment.

The agent does not access 1Password. Tell the user which existing credential is
needed and where to enter it. Provide commands with placeholders so the user can
configure the local CLI without sending values into chat. Do not create
replacements. If an item cannot be found, ask the user to locate it in 1Password
or request access from the owner.

### 1.2 GitHub

Check current authentication:

```bash
gh auth status --hostname github.com
```

When not authenticated, tell the user to take the existing GitHub credential
from 1Password and complete the interactive login locally. Confirm access to:

- the target application repository;
- `AiDigital-com/AIAE-helm`;
- `AiDigital-com/AIAE-helm-versions`;
- `AiDigital-com/AIAE-aws-infra`.

For the workflow GitOps credential, use the already approved token from
1Password. Confirm organization approval and `Contents: Read and write` on both
GitOps repositories. Do not print or test it in a URL.

### 1.3 AWS

List existing profiles:

```bash
aws configure list-profiles
```

Prefer existing Identity Center profiles. When a login is required:

```bash
aws sso login --profile <profile>
```

Verify identities:

```bash
aws sts get-caller-identity --profile <dev-profile>
aws sts get-caller-identity --profile <prod-profile>
```

Expected account IDs are `496336474487` for DEV and `125093118532` for PROD.
Stop on mismatch.

If the existing access uses a different approved mechanism stored in
1Password, give the user placeholder-based configuration commands and wait for
them to finish. Do not create a new IAM user or access key.

## Phase 2: Prepare the workspace

Choose a workspace directory with enough disk space and no repository-name
collisions. Locate repositories by remote URL. Clone only missing repositories:

```bash
gh repo clone AiDigital-com/AIAE-helm <workspace>/AIAE-helm
gh repo clone AiDigital-com/AIAE-helm-versions <workspace>/AIAE-helm-versions
gh repo clone AiDigital-com/AIAE-aws-infra <workspace>/AIAE-aws-infra
gh repo clone <owner>/<application-repository> <workspace>/<application-repository>
```

For existing checkouts:

- inspect origin URL;
- fetch remote references;
- inspect branch and worktree status;
- do not switch or clean a dirty checkout;
- use a separate worktree when required branches are already checked out;
- inspect remote `main`, `dev`, and `prod` contents directly instead of assuming
  the current local branch represents all of them.

Run the preflight helper again with selected AWS profiles.

```bash
bash <installed-skill-directory>/scripts/preflight.sh \
  --workspace <workspace> \
  --app-repo <owner>/<application-repository> \
  --mode dev \
  --dev-profile <dev-profile>
```

Use `--mode prod --prod-profile <prod-profile>` for PROD, or `--mode all` with
both profiles when both environments must be ready. A deployment mode must end
with `Status: PASS`; `inspect` is discovery-only and may report warnings.

## Phase 3: Analyze the application and Replit migration

Follow `application-intake.md`. If Replit artifacts exist, follow
`replit-migration.md` and produce the migration matrix.

The analysis must result in:

- deployable unit list;
- build/test/container commands;
- ports and health endpoints;
- application and migration image contracts;
- frontend build/output contract;
- runtime and build-time configuration inventory;
- exact secret key names without values;
- database and migration design;
- public paths and hostnames;
- scaling/resources;
- logging/metrics needs;
- Replit replacements and deletion candidates.

Do not start by copying Operational Hub files. First prove which parts apply.

## Phase 4: Design application-scoped AWS resources

Inspect `AIAE-aws-infra` and current Terraform state. Build a table:

| Resource | Shared/reused | New per app | Not needed | Manual |
|---|---|---|---|---|
| VPC/EKS/Argo/OIDC provider | expected shared | | | |
| ECR/CI role/application IAM/secret | | usually | | |
| RDS/frontend/domain | | when justified | when absent | DNS may be manual |

The current root is not a reusable per-app stack. Add application-scoped
resources without recreating shared ones. For the first additional application,
prefer adding clearly keyed resources/locals in the existing state while
preserving current Operational Hub addresses. A broader state/module migration
is separate work and must have zero-destroy evidence.

Before accepting the workload into the shared environment, capture EKS
allocatable/requested CPU and memory, pending/unschedulable Pods, autoscaler
ceiling, subnet IP capacity, namespace quotas, relevant ELB quotas, and the
projected RDS connection total. If capacity is insufficient, stop application
onboarding and present the shared-capacity change as a separate reviewed action.

### Required per-app IAM boundaries

The GitHub CI role trust must include only the application's approved `dev` and
`prod` GitHub environments. Query numeric organization/repository IDs when the
custom subject template requires them.

The CI policy should grant only:

- ECR operations on that application's repository;
- frontend S3/CloudFront operations when it has a frontend;
- read access to that application's build configuration secret;
- no Kubernetes credentials.

The workload ServiceAccount role should grant only the AWS APIs the application
uses, including its Secrets Manager secret.

### Secret creation and population

Terraform creates the secret container and outputs its name. It must not place
user secret values into state.

Give the user a no-value checklist such as:

```text
AWS Secrets Manager secret: AIAE-DEV/example-application
Required JSON keys:
- POSTGRES_HOST
- POSTGRES_PORT
- POSTGRES_DB
- POSTGRES_USER
- POSTGRES_PASSWORD
- EXTERNAL_API_TOKEN
```

Provide a separate PROD checklist. The user populates values from approved
sources, commonly 1Password or RDS-managed credentials.

Secrets Manager metadata cannot prove which JSON keys exist. To validate a
secret without exposing values to the agent, give the user this local pattern
and replace the placeholders with the required key list:

```bash
(
  set -euo pipefail
  export EXPECTED_KEYS='["DB_USERNAME","DB_PASSWORD"]'
  export AWS_PROFILE='<environment-profile>'
  export SECRET_ID='<environment/application>'

  if ! secret_json="$(aws --profile "$AWS_PROFILE" secretsmanager \
    get-secret-value --secret-id "$SECRET_ID" --query SecretString \
    --output text 2>/dev/null)"; then
    echo 'ERROR: secret retrieval failed' >&2
    exit 3
  fi
  if ! printf '%s' "$secret_json" | jq -e 'type == "object"' >/dev/null; then
    echo 'ERROR: secret is not a JSON object' >&2
    exit 4
  fi

  actual_keys="$(printf '%s' "$secret_json" | jq -c 'keys')"
  missing_keys="$(jq -n --argjson expected "$EXPECTED_KEYS" \
    --argjson actual "$actual_keys" '$expected - $actual')"
  unset secret_json actual_keys

  if [ "$missing_keys" = '[]' ]; then
    echo PASS
  else
    echo "Missing keys: $missing_keys"
  fi
)
```

The user runs it locally and reports only `PASS` or missing key names. The agent
must not run it, request its payload, enable shell tracing, or capture command
output containing values. Exit `3` means retrieval/access failure; exit `4`
means the stored value is not a JSON object. These categories reveal no secret
value.

## Phase 5: Validate and apply Terraform

From `AIAE-aws-infra`, run formatting, tests, and static initialization first:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
helm lint charts/cluster-bootstrap
```

Use an isolated worktree or restore backend initialization before the real plan.
Configure the AWS provider with the target environment as its only
`allowed_account_ids` entry. Ensure backend configuration does not select a
different profile. For DEV, run identity check, backend initialization, plan,
and plan rendering inside one credential scope:

```bash
(
  set -euo pipefail
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
    AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN AWS_DEFAULT_PROFILE \
    AWS_CONTAINER_CREDENTIALS_RELATIVE_URI AWS_CONTAINER_CREDENTIALS_FULL_URI
  export AWS_PROFILE='<dev-profile>'
  export AWS_REGION='us-east-1'
  export AWS_DEFAULT_REGION="$AWS_REGION"
  export AWS_SDK_LOAD_CONFIG=1

  account_id="$(aws sts get-caller-identity --query Account --output text)"
  [ "$account_id" = '496336474487' ] || {
    echo "Wrong AWS account: $account_id" >&2
    exit 1
  }

  terraform init -reconfigure -backend-config=backend-config/dev.hcl \
    -backend-config="profile=$AWS_PROFILE"
  terraform plan -var-file=env/dev.tfvars -out=<dev-plan-file>
  terraform show <dev-plan-file>
)
```

Summarize:

- create/update/delete/replace counts;
- every database, cluster, VPC, IAM trust, public endpoint, certificate, secret,
  and state-impacting action;
- expected monthly-cost categories;
- manual actions after apply.

Require confirmation for the displayed plan. Apply the saved plan, not a newly
calculated unreviewed plan. Re-enter the same credential scope, repeat the
ambient identity check without `--profile`, and run
`terraform apply <dev-plan-file>` there. If credentials expired, backend state
changed, the plan became stale, or any input changed, create and review a new
plan instead of bypassing the gate.

Repeat independently for PROD only in prepare/release scope. Never assume the
backend remains initialized for the other environment.

After apply, collect non-sensitive outputs:

- GitHub CI role ARN;
- ECR repository URL;
- application IAM role ARN;
- application secret name;
- optional RDS endpoint/port/database name;
- optional frontend bucket, CloudFront distribution ID and URL;
- optional ACM validation records;
- shared EKS and Argo identifiers.

Do not output passwords or SecretString.

## Phase 6: Build the Helm and Argo contract

### 6.1 Chart structure on `AIAE-helm/main`

For an application matching the existing Spring backend pattern, use the
current chart as an implementation reference. Either create a correctly renamed
application chart or extract a generic chart only when that refactor is fully
render-tested and does not change Operational Hub resources.

Check all name-specific helpers and selectors. A copied chart with old helper
names can collide with the existing application.

Include only required objects:

- Deployment and Service;
- ServiceAccount with the per-app IAM role;
- ConfigMap;
- Secrets Store `SecretProviderClass` and key mapping;
- startup/readiness/liveness probes;
- Ingress paths and ALB annotations;
- HPA/PDB according to environment needs;
- PreSync migration Job only when the application has migrations.

Render manifests for DEV and PROD and inspect names, namespace, image source,
secret name, paths, probes, IAM annotations, and sync waves.

### 6.2 Versions on `AIAE-helm-versions/main`

Create one folder/value file per deployable backend. It contains exact image
tags and the deployment revision. Do not put environment configuration or
secrets there.

### 6.3 Environment catalog on `AIAE-helm/dev` and `prod`

Add one child Application template per deployable backend and a corresponding
service entry in values.

The child Application should:

- target the existing shared namespace;
- read chart structure from a pinned `AIAE-helm/main` revision;
- read image values from a pinned `AIAE-helm-versions/main` revision;
- use the per-app ECR, IAM role, and secret;
- use environment-specific replicas/config/routes;
- enable automated sync, prune, self-heal, and namespace creation;
- retain unrelated applications in the environment root.

Use `aiae-dev-root` and `aiae-prod-root`; do not create an application-specific
root.

## Phase 7: Build application workflows

Adapt the three workflow roles to the actual repository:

1. DEV on push to the one configured numbered deployment branch;
2. manual PROD release from the matching numbered branch;
3. manual PROD rollback to an existing complete release.

Workflows should:

- use GitHub OIDC and no permanent AWS key;
- validate required variables conditionally;
- build/test according to repository policy;
- build immutable application and migration images when applicable;
- build and upload frontend when applicable;
- update only the application's version file;
- pin the resulting versions revision in the correct environment branch;
- serialize the shared GitOps publication boundary;
- preserve restorable PROD release metadata;
- never receive Kubernetes credentials.

Because these workflows live in different application repositories,
repository-local `concurrency` only prevents duplicate runs for one app. At each
shared GitOps publication boundary, implement a bounded optimistic loop:

1. fetch the latest target branch;
2. create a clean temporary worktree at that remote head;
3. change only this application's file/field;
4. publish fast-forward-only;
5. on non-fast-forward, discard the temporary attempt and retry from the new
   remote head;
6. stop after the configured retry limit and report a visible failure;
7. verify unrelated application entries remain present.

Never force-publish a shared GitOps branch.

Remove assumptions for components the app does not have. A backend-only service
must not require frontend variables. An app without Liquibase must not build a
migration image.

## Phase 8: Configure GitHub environments

For `dev` and `prod`, provide the user a table with exact values from Terraform
outputs. Use these canonical names; do not invent aliases or application-specific
renames.

Required variables for every application and both environments:

```text
AWS_ROLE_TO_ASSUME
AWS_REGION
APP_CONFIG_SECRET_NAME
GITOPS_HELM_REPOSITORY
GITOPS_VERSIONS_REPOSITORY
```

Conditional variables:

```text
DEV_DEPLOY_BRANCH          # required in DEV only
FRONTEND_BUCKET            # required only when the app deploys a frontend
FRONTEND_DISTRIBUTION_ID   # required only when the app deploys a frontend
```

Required environment secret for every application:

```text
GITOPS_TOKEN
```

Therefore a frontend-enabled PROD environment has seven variables plus one
secret. A frontend-enabled DEV environment has eight variables plus one secret.
A backend-only application omits both frontend variables. Add another variable
or secret only when the reviewed workflow actually consumes it; document the
consumer and source beside it. Validate that workflow references and GitHub
environment names match this matrix exactly so a rename fails before build or
AWS mutation.

The value comes from the existing approved 1Password item. Tell the user where
to enter it. Do not ask for the value in chat and do not create a new token.

Verify environment names match the IAM OIDC subjects exactly.

## Phase 9: Publish and deploy DEV

Use AWS-generated endpoints for DEV. A frontend-enabled application is opened
through its generated CloudFront domain; a backend-only application is tested
through its generated ALB endpoint. Do not request GoDaddy records, create a
custom DEV hostname, or request a dedicated DEV ACM certificate. Configure the
application's DEV auth callbacks/authorized parties, CORS, and CSP for the
generated CloudFront origin when those controls apply.

Only depart from this default when repository or integration evidence proves
that a stable allowlisted callback/webhook hostname is required. Record that
requirement and obtain explicit user approval before adding DEV DNS or ACM
resources.

Before remote publication, show:

- repository and target branch;
- changed files;
- intended commit message;
- expected workflow trigger;
- current remote head and conflict check.

Proceed only with explicit authorization. Preserve unrelated changes in shared
GitOps repositories.

Trigger the DEV flow through the configured numbered branch. Follow the entire
chain using `verification-and-recovery.md`.

If Replit cleanup is part of the migration, remove Replit-only artifacts only
after replacements exist, then rebuild and redeploy DEV. Keep the old hosted
application available until PROD cutover is verified.

## Phase 10: Prepare PROD

Custom hostnames, ACM validation, and GoDaddy traffic cutover belong to this
PROD phase unless a DEV exception was explicitly approved in Phase 9.

Repeat infrastructure planning against the PROD backend/profile. Verify:

- no public PROD database;
- backup retention and deletion protection;
- Multi-AZ and replica baseline when required;
- PROD Secrets Manager keys present;
- custom hostname and ACM validation status;
- production GitHub environment and OIDC trust;
- Argo child Application rendered for `aiae-prod`;
- PROD logging/metrics integration;
- release/rollback artifacts and database compatibility.

When DNS is external, give the user plain copyable records:

```text
ACM validation
Type: CNAME
Host: <validation host without accidental duplicate zone suffix>
Value: <acm-validations.aws target>

Traffic cutover
Delete old provider A/TXT records only after verification.
Type: CNAME
Host: <application host label>
Value: <cloudfront domain>
Keep the ACM validation CNAME.
```

Wait for ACM `ISSUED` before attaching an HTTPS listener/custom CloudFront alias.

### Choose one-step or two-step external DNS

Before contacting the GoDaddy administrator, inspect ACM certificates in
`us-east-1` and determine whether an existing `ISSUED` exact-name or wildcard
certificate covers the final hostname and may be reused.

Confirm whether the requested hostname is a subdomain or the DNS zone apex. The
messages below use a subdomain CNAME. For a zone apex, verify GoDaddy's current
apex forwarding/flattening capabilities and produce the supported record type;
otherwise select a subdomain. Do not request a normal apex CNAME.

Use one administrator iteration only when:

- the certificate is already `ISSUED` and covers the final hostname;
- the CloudFront distribution status is `Deployed`;
- its aliases contain the exact final hostname and its viewer certificate is the
  expected ACM certificate;
- the generated CloudFront endpoint and API origin pass smoke tests;
- pre-cutover requests using the final hostname pass TLS/SNI, frontend, API,
  authentication redirect, CORS, and CSP checks;
- the only remaining action is traffic CNAME replacement.

Verify CloudFront configuration and test the final hostname before DNS cutover:

```bash
aws --profile <prod-profile> cloudfront get-distribution \
  --id <distribution-id> \
  --query 'Distribution.{Status:Status,Aliases:DistributionConfig.Aliases.Items,Certificate:DistributionConfig.ViewerCertificate.ACMCertificateArn}'

edge_ip="$(dig +short <cloudfront-domain> A | head -n 1)"
test -n "$edge_ip"
curl --fail --silent --show-error \
  --resolve '<final-host>:443:'"$edge_ip" \
  'https://<final-host>/' >/dev/null
curl --fail --silent --show-error \
  --resolve '<final-host>:443:'"$edge_ip" \
  'https://<final-host>/<public-api-health-path>' >/dev/null
curl --silent --show-error --head \
  --resolve '<final-host>:443:'"$edge_ip" \
  -H 'Origin: https://<final-host>' \
  'https://<final-host>/<login-or-api-path>'
```

Inspect the last response for expected redirect, CORS, and CSP headers. Use the
application's actual public health/login paths; do not expose an internal-only
endpoint for this test. If the exact alias/certificate or final-host test cannot
be proven, do not use the one-iteration path. Use a staged/two-iteration request
with `WAIT FOR PLATFORM READY CONFIRMATION`.

Before cutover, capture the exact old records, current TTL, tested CloudFront
domain, observation window, rollback threshold, and ready-to-send rollback
records. Where operationally possible, lower TTL at least one old-TTL interval
before cutover.

Provide this message:

```text
Please switch the production DNS record for <application> in GoDaddy.

Delete the old hosting records for <host>:
<exact old records>

Add:
Type: CNAME
Host: <host label>
Value: <cloudfront-domain>

Do not delete the existing ACM validation CNAME:
Host: <validation host>
Value: <validation value>

Rollback if <agreed TLS/5xx/login/API threshold> persists for
<observation window>:
Remove the new traffic record and restore:
<exact old records>
```

Use two administrator iterations when a new certificate needs DNS validation.
First message:

```text
Please add this ACM validation record in GoDaddy. Keep it permanently.

Type: CNAME
Host: <validation host>
Value: <validation value>

Please do not change the current application traffic record yet. The platform
team will send a separate cutover request after ACM and CloudFront are ready.
```

After ACM is `ISSUED`, CloudFront has the alias, and AWS endpoint tests pass,
send the traffic-cutover message above. If one ticket must contain both steps,
mark step 2 `WAIT FOR PLATFORM READY CONFIRMATION`; do not authorize immediate
execution of both.

## Phase 11: Release and verify PROD

Require explicit confirmation containing application, version branch, commit,
PROD account, plan summary, endpoint, and migration note.

Run the manual release workflow from the matching numbered branch. Verify the
whole chain. Cut DNS only after the AWS-generated endpoint works. Retire the old
provider only after external DNS/TLS/login/API/data/log/metric verification and
a known rollback target.

## Phase 12: Final handoff

Produce a concise record with:

- application contract;
- repositories, branches, revisions, and changed files;
- AWS resources created/reused;
- GitHub environments and secret names;
- deployed image/migration/frontend release identifiers;
- Argo root/child and namespace;
- endpoints and DNS records;
- tests and live verification;
- Replit artifacts removed and remaining references;
- cost-impact categories;
- rollback procedure;
- unresolved manual work.
