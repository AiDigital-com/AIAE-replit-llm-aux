# Verification and Recovery

Use fresh evidence. Do not infer live success from Terraform source, a workflow
definition, or an Argo screenshot from an earlier release.

## Verification status

Use exactly one status:

- `VERIFIED`: all requested environments and user-visible paths were checked.
- `PARTIALLY_VERIFIED`: implementation exists but one or more live boundaries
  lack evidence.
- `BLOCKED`: a credential, approval, external action, failed gate, or unsafe plan
  prevents progress.
- `FAILED`: observed behavior does not meet the deployment contract.

## 1. Repository evidence

For each repository record:

- canonical origin;
- branch and exact commit;
- clean/dirty status and unrelated changes;
- changed files;
- remote branch revision after publication;
- no secret values in diff/history;
- shared maps/values still contain other applications.

Inspect the actual remote environment branches. Do not verify PROD from a DEV
checkout.

## 2. Application evidence

Run repository-defined checks for every affected unit:

- backend compile and tests;
- frontend install, typecheck/tests, and production build;
- application and migration container builds;
- startup with representative non-secret configuration when feasible;
- health endpoints;
- repository-wide search for removed Replit profiles/domains/scripts;
- configuration-key inventory matches code.

When tests are intentionally skipped in a deployment workflow, confirm an
earlier required CI workflow protects the same revision. Do not merely assume it.

## 3. Terraform evidence

Before apply:

- selected profile account equals the target environment;
- backend bucket/key equals the environment;
- state lock is acquired;
- formatting, validation, tests, and Helm bootstrap lint pass;
- saved plan has expected create/update counts;
- no unexplained deletes/replacements;
- shared VPC/EKS/Argo/OIDC/CodeConnections resources are unchanged;
- database replacement is absent unless explicitly intended;
- sensitive values are not printed.

After apply:

- apply used the reviewed plan and completed successfully;
- a new plan is empty or contains only documented asynchronous drift;
- outputs match the GitHub/Helm configuration;
- ECR, IAM roles, secret container, optional RDS/frontend/certificate exist;
- CodeConnections is `AVAILABLE` when Argo requires it;
- ACM is `ISSUED` before custom HTTPS attachment.

## 4. GitHub Actions evidence

Record workflow URL/run ID, source branch/SHA, GitHub environment, assumed-role
account, and result.

Confirm:

- OIDC assumption succeeds without a permanent AWS key;
- image tags equal the expected revision;
- application and migration image existence checks are correct;
- frontend build/upload happens only when applicable;
- versions file contains the expected tags;
- environment branch pins the versions commit produced by the run;
- shared GitOps publication did not remove another application's change;
- PROD release metadata exists before declaring rollback available.

## 5. AWS artifact evidence

Without printing secret values, verify:

- ECR repository exists and expected immutable tags resolve to image digests;
- application/migration image pair is complete;
- lifecycle policy matches DEV/PROD retention intent;
- secret exists, and the user-side key checker reports `PASS` or only the names
  of missing keys; the agent does not retrieve `SecretString` for this check;
- CI role trust subject matches repository/environment IDs;
- workload role trust matches namespace/ServiceAccount names;
- optional RDS status is `available`, network mode matches environment, backups
  and deletion protection match the contract;
- frontend bucket has `index.html` and release metadata;
- CloudFront distribution is deployed and invalidation completed when needed;
- certificate and DNS validation status are correct.

## 6. Kubernetes and Argo evidence

Update kubeconfig with the selected environment profile only after account
verification. Check the shared namespace.

Verify:

- root Application is Healthy and Synced;
- child Application exists, is Healthy and Synced;
- child sources point to intended chart and versions revisions;
- no stale duplicate child/root owns the same resources;
- PreSync migration Job completed for the intended migration image;
- Deployment observed generation matches desired generation;
- rollout completed and desired/ready/available replicas agree;
- all pods use the expected image digest and are Ready;
- Service endpoints contain the ready pods;
- SecretProviderClass exists and synchronized Kubernetes Secret has expected key
  names, without printing data;
- Ingress/ALB targets are healthy and route the intended path;
- probes succeed and are not blocked by authentication;
- HPA/PDB match environment expectations.

## 7. User-visible smoke tests

Test from outside the cluster:

- generated CloudFront URL before custom DNS cutover;
- custom hostname after DNS propagation;
- TLS certificate hostname and issuer;
- frontend loads with no stale Replit origin;
- direct navigation to an SPA route works;
- API health and representative authenticated/unauthenticated behavior;
- login/Clerk redirect/authorized parties/CORS/CSP;
- one safe database-backed read and, when approved, a reversible write;
- application logs appear in the intended environment;
- production metrics and dashboards receive fresh data.

Do not use an actuator response alone as proof that the product works.

## 8. DNS verification

Check authoritative and public resolution. Account for TTL but distinguish
propagation from incorrect records.

Verify:

- ACM validation CNAME still exists;
- application hostname resolves to the intended CloudFront distribution;
- old provider A/TXT traffic records are absent after cutover;
- TLS serves the expected certificate;
- CloudFront reaches the ALB API origin;
- rollback DNS instructions are recorded before retiring the old provider.

## 9. Common recovery paths

### OIDC assumption denied

Check account, workflow environment, audience, customized subject, numeric
organization/repository IDs, OIDC provider ARN, and trust-policy deployment.
Do not add wildcard repository trust.

### ECR access denied

Use the denied action and repository ARN from the error. Add only the missing
operation required by the workflow, apply IAM, then rerun. Known required read
operations include `BatchGetImage` and `DescribeImages`.

### GitOps repository 403

Check that the existing 1Password token is organization-approved, covers both
GitOps repositories, has contents write permission, and is stored in the correct
GitHub environment. Do not create a second token.

### Argo child missing

Check the root's environment branch/revision, child template render, enabled
flag, AppProject, CodeConnections state, and Argo events. Refreshing Argo cannot
fix a child manifest that was never rendered.

### Argo OutOfSync or Degraded

Inspect resource events and source revisions. Determine whether Git is wrong,
live resources are unhealthy, or reconciliation lacks IAM/Kubernetes access.
Do not repeatedly force sync without understanding the failing resource.

### Migration Job failed

Inspect Job events/logs, image tag, Maven/migration command, secret key mapping,
RDS DNS/network, credentials, changelog locks, and schema error. The Deployment
must remain blocked until migration is resolved or safely rolled back.

### ALB certificate error

Do not configure HTTPS until the correct ACM certificate ARN exists and is
issued. For CloudFront, the certificate must be in `us-east-1`. Confirm listener
annotations and hostname ownership.

### Frontend works but API fails

Check CloudFront behavior path, API origin hostname/protocol, ALB listener,
Ingress path, backend path expectations, target health, CORS, and authorized
parties.

### Database unreachable

Check RDS status, endpoint/port/database, public/private flag, subnet route,
security group source, network ACL, DNS, TLS, and credential secret mapping.
Never expose PROD publicly as a diagnostic shortcut.

### Terraform proposes database or cluster replacement

Stop. Identify the changed address/immutable property, compare state and code,
restore unintended naming/config drift, or design an explicit migration with
backup/import/moved-state evidence. Do not apply first and investigate later.

## 10. PROD rollback gate

A rollback target is valid only when all are available:

- application image;
- matching migration image when migrations exist;
- frontend release files and metadata when a frontend exists;
- versions values that reference the pair;
- known source revision;
- database schema compatible with the older application.

Use the manual rollback workflow to repin existing artifacts. Do not rebuild an
old source revision and call it the same release.

After rollback, repeat Argo, rollout, endpoint, login, database, log, and metric
checks. Record whether database state was changed separately.

## 11. Final evidence format

```text
STATUS: VERIFIED | PARTIALLY_VERIFIED | BLOCKED | FAILED

Application:
- name, repository, source revision, release version

Repositories:
- application
- AIAE-helm main/dev/prod
- AIAE-helm-versions main
- AIAE-aws-infra main

AWS:
- DEV account/profile and plan/apply result
- PROD account/profile and plan/apply result
- resources created/reused

Deployment:
- image and migration tags/digests
- frontend release
- Argo root/child revisions and health
- migration and rollout result

Smoke tests:
- URLs and observed results

Secrets:
- secret names and key-presence status only

Replit migration:
- removed artifacts
- remaining intentional references
- old deployment retirement status

Manual actions:
- DNS, secret population, organization approval, or none

Rollback:
- selected restorable release and migration compatibility

Not verified:
- gap and reason
```
