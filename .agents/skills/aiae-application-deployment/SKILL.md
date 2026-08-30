---
name: aiae-application-deployment
description: Onboard, deploy, verify, or recover an AIAE application on the shared AWS DEV and PROD platform using AIAE-aws-infra, AIAE-helm, AIAE-helm-versions, GitHub Actions, and Argo CD. Use for end-to-end AIAE deployment work, not generic AWS or Kubernetes advice.
---

<!--
Generated file. Do not edit directly.
Source: AIAE-llm-aux/skills/aiae-application-deployment/SKILL.md
Revision: 7b84eb81c4b9ac2afc9ae633dc96f8e4c18522ba
Target: agents
-->


# AIAE Application Deployment

Operate the real AIAE deployment model from discovery through DEV verification
and, when explicitly requested, PROD release or rollback.

The workflow spans four repositories and two AWS accounts. Do not treat a
successful change in one repository as a completed deployment.

## Load the platform contract

Before planning or changing anything:

1. Read [references/platform-context.md](references/platform-context.md).
2. Read [references/lessons-learned.md](references/lessons-learned.md) so known
   failure modes are handled before they recur.
3. Read [references/application-intake.md](references/application-intake.md)
   and build the application contract from repository evidence plus the user's
   business requirements.
4. If the source contains `.replit`, `replit.nix`, a Replit deployment profile,
   Replit-only scripts, or Replit domains, read
   [references/replit-migration.md](references/replit-migration.md).
5. For onboarding or deployment, read
   [references/onboarding-runbook.md](references/onboarding-runbook.md).
6. Before claiming success, read
   [references/verification-and-recovery.md](references/verification-and-recovery.md).

Treat the references as the verified baseline, not timeless truth. Inspect the
current remote branches, Terraform configuration, workflows, and live AWS state
before mutation. When the baseline and current state differ, current repository
and live-state evidence wins; record the drift.

## Supported modes

Infer the narrowest mode or ordered sequence of modes that satisfies the
request. A request may intentionally compose modes, for example
`onboard-dev -> prepare-prod`; complete and verify each mode before entering
the next one:

- **inspect**: read-only platform, repository, auth, or runtime status.
- **plan**: produce a cross-repository change and deployment plan without
  mutation. This is the default when intent is ambiguous.
- **onboard-dev**: prepare a new application and deploy it to DEV.
- **prepare-prod**: create and validate PROD repository configuration and
  Terraform plans, but do not apply PROD Terraform or release the application
  unless the user explicitly includes that mutation in the request.
- **release-prod**: run the existing manual PROD release flow after an explicit
  production confirmation.
- **rollback-prod**: select an existing complete release and run the existing
  rollback flow after explicit confirmation.
- **recover**: diagnose and repair a failed deployment without widening scope.

Do not silently escalate from inspect or plan into mutation. A request to
"onboard" or "deploy to DEV" authorizes the corresponding non-destructive work,
but not destructive Terraform actions or a PROD release.

## Required operating rules

### Protect credentials

- Prefer GitHub CLI authentication and AWS IAM Identity Center profiles.
- Existing AWS login material and the approved GitHub/GitOps token are stored in
  the team's 1Password vault. Tell the user which existing item/purpose to use
  and where to enter it. The agent must not access 1Password directly. Do not
  create a new IAM user, access key, personal access token, SSH key, or
  replacement credential.
- Provide commands with placeholders so the user enters credentials locally or
  completes the browser/console flow. Never ask the user to send the value back
  in chat or place it in process arguments, logs, generated files, or shell
  history.
- If the required 1Password item is missing, expired, or lacks organization
  approval, stop and report the exact missing access. Do not silently generate a
  substitute.
- Never request that access keys, passwords, tokens, private keys, or secret
  values be pasted into chat or committed to a repository.
- Let the user complete browser, MFA, GitHub App, CodeConnections, and SSO
  approval screens when required.
- Inspect secret names, ARNs, and metadata only. Secrets Manager metadata does
  not expose JSON keys. When key validation is required, give the user a local
  command that retrieves and checks the secret without printing values; ask the
  user to return only `PASS` or the missing key names. The agent must not run
  that value-reading command or receive its payload.

### Protect AWS environments

- Expected DEV account: `496336474487`.
- Expected PROD account: `125093118532`.
- Expected region: `us-east-1`.
- Bind Terraform and the identity check to the same credential scope. Clear
  conflicting ambient AWS credential variables, export the selected
  `AWS_PROFILE`, `AWS_REGION`, `AWS_DEFAULT_REGION`, and
  `AWS_SDK_LOAD_CONFIG=1`, then run `aws sts get-caller-identity` without a
  profile override in that same scope. Compare its account ID to the target
  environment immediately before init/plan and again before applying the saved
  plan. Require the AWS provider's `allowed_account_ids` to contain only that
  environment account. Do not run Terraform outside this scope.
- Never use the DEV profile for PROD or the PROD profile for DEV.
- Never run Terraform destroy unless the user explicitly requests destruction,
  sees the destroy plan, and confirms it.
- Refuse an apply containing unexpected deletes or replacements. Explain the
  affected data, networking, cluster, identity, and public endpoint impact.

### Preserve the shared platform

DEV and PROD each have one shared AIAE EKS cluster and one environment root
application. A new application is normally a new child application inside the
existing environment, not a new cluster.

Do not duplicate or recreate the shared VPC, subnets, NAT, EKS cluster, Argo CD
capability, GitHub OIDC provider, CodeConnections connection, Secrets Store CSI
driver, namespace, root application, or production observability stack.

Before admitting another workload, check shared capacity and quotas: schedulable
CPU/memory, pending Pods, node/autoscaler limits, namespace quotas, IP/subnet
headroom, ALB/target-group/listener quotas, and expected RDS connection usage.
Do not deploy when the new workload can predictably degrade existing
applications; report the required capacity change separately.

The current Terraform root contains both shared platform resources and
Operational Hub-specific resources. Never copy the root and apply it under a new
state key for another application. Extend it with application-scoped resources
without renaming existing addresses, or first perform an explicitly reviewed
state/module migration.

### Control observability identities and cost

- Maintain Grafana dashboards through the UI as an existing Identity Center
  administrator. Never create a Grafana service account, API user, or API token
  solely to import, update, or delete dashboards.
- If no existing administrator can make the change, stop and request an
  administrator assignment. A temporary API identity is not an acceptable
  workaround because Amazon Managed Grafana may bill it as an active editor.
- Keep the default managed-metrics scope to application/API, JVM, HikariCP,
  cache, external-query, and PostgreSQL metrics. Add Kubernetes/node, edge,
  deployment-marker, log-query, or paid CloudFront metrics only for a verified
  operational requirement after stating the recurring cost.

### Protect repositories and Git history

- Discover checkouts by their `origin` remote, not by local directory name.
- Fetch before comparing branches, but do not switch a dirty checkout, discard
  changes, delete branches, or overwrite another worktree.
- Inspect `main`, `dev`, and `prod` independently. A local current branch does
  not represent the other environment branches.
- Keep product source, chart structure, version pins, environment catalog, and
  Terraform changes in their owning repositories.
- Do not publish commits or remote branch changes without explicit user
  authorization. Before requesting it, show repositories, files, branch names,
  and intended commit messages.
- Updates to `AIAE-helm-versions/main` and environment branches come from
  separate application repositories, so repository-local GitHub concurrency
  cannot serialize them globally. Use an optimistic publication loop: fetch the
  latest remote head, reapply only this application's change, publish with a
  fast-forward-only operation, and retry on non-fast-forward after re-reading
  the remote. Bound retries and fail visibly rather than force-writing. Preserve
  unrelated application entries and verify them after publication.

### Protect production

- Complete and verify DEV first unless the user is performing an emergency
  recovery with a known release artifact.
- PROD is always manual. A version branch or DEV deployment does not authorize a
  production release.
- Require a fresh confirmation that names the application, version, source
  revision, PROD account, Terraform plan summary, and expected endpoint.
- Database migration compatibility is part of release and rollback safety.
  Never claim an application rollback is safe when Liquibase changes are not
  backward compatible.

## End-to-end workflow

### 1. Establish a run record

State the selected mode and maintain a checklist containing:

- application identity and source repository;
- DEV and PROD AWS profiles;
- four repository paths and checked revisions;
- application contract decisions;
- planned resources and repository files;
- approvals received;
- commands and verification evidence;
- remaining manual actions such as DNS or secret population.

Do not mark a phase complete from intention or a code diff alone.

### 2. Run read-only preflight

Locate this skill directory and run:

```bash
bash scripts/preflight.sh --workspace <workspace> \
  --app-repo <owner/repository> --mode inspect
```

Resolve `scripts/preflight.sh` relative to this skill directory. Before DEV or
PROD work, rerun with `--mode dev`, `--mode prod`, or `--mode all` and the
corresponding profile option(s). Deployment modes require `Status: PASS`; the
helper exits nonzero on blockers. It remains read-only and redacts remote
credentials. Use its result to identify missing CLI tools, authentication,
checkouts, dirty repositories, and AWS account mismatches.

If GitHub or AWS authentication is missing, follow the interactive auth section
of the onboarding runbook and rerun preflight. Do not continue with guessed
credentials.

### 3. Discover before designing

Inspect the application repository and determine actual build paths,
Dockerfiles, health endpoints, migration mechanism, frontend output, secrets,
external integrations, and existing workflows. Do not assume the Operational
Hub module layout applies to every application.

Infer the required infrastructure from application evidence. Backend, frontend,
database, migration, scheduled job, object storage, external API, authentication,
custom domain, and observability needs each imply different resources. Do not
create an Operational Hub-shaped stack merely because it is the reference.

When Replit artifacts exist, create a migration matrix before deleting anything:
record each Replit command, port, profile, environment key, public configuration,
secret key name, domain, health check, and runtime assumption; map it to its AWS,
GitHub, Helm, or application-code replacement. Populate no secret values on the
user's behalf. Give the user the exact Secrets Manager secret name and required
JSON keys, and verify key presence without displaying values.

Inspect current remote state of:

- `AiDigital-com/AIAE-helm` branches `main`, `dev`, and `prod`;
- `AiDigital-com/AIAE-helm-versions` branch `main`;
- `AiDigital-com/AIAE-aws-infra` branch `main`;
- the target application's source and release branches.

Inspect live shared resources in both accounts when access is available. Report
unknowns instead of inventing values.

### 4. Build the application contract

Use the intake reference. Resolve technical choices from repository and platform
evidence. Ask the user only for business-facing facts, required credentials, a
public hostname decision, database access needs, or an irreversible/high-impact
choice.

Explicitly classify every proposed AWS resource as:

- **shared and reused**;
- **application-scoped and new**;
- **not required**;
- **manual external action**.

This classification is mandatory before Terraform changes.

### 5. Produce the cross-repository plan

Name exact files and branches for every required change. Include:

- application source workflows and Docker build contract;
- application-scoped Terraform resources and outputs;
- reusable or application-specific Helm chart changes on `main`;
- application version values on `AIAE-helm-versions/main`;
- child Application templates and values on both environment branches;
- GitHub environment variables/secrets that the user must configure;
- secrets that must exist in AWS Secrets Manager;
- DEV verification, PROD preparation, rollback, and DNS steps.

Show the plan before live mutation. For Terraform, include the resource counts
and every delete/replace action, not only a prose summary.

### 6. Implement and validate locally

Follow repository-local instructions. Preserve unrelated user changes. Use the
actual application build and test commands discovered from its repository.

Validate each affected layer before AWS mutation:

- application tests and production builds;
- both Dockerfiles or the actual container build path;
- Helm lint and rendered manifests for DEV and PROD;
- Terraform formatting, initialization without backend where applicable,
  validation, tests, and environment plans;
- workflow YAML structure and required variable names;
- no secret values in diffs or generated output.

After AWS replacements are present and DEV verification passes, first determine
whether the live Replit deployment auto-deploys from the branch being edited.
Preserve its last known-good revision and either freeze/detach that deployment
or defer cleanup until the AWS PROD cutover and stabilization window complete.
Only then remove Replit-only profiles, deployment scripts, metadata, domains,
and unused configuration. Search the full repository for remaining references
and retain anything still required for local development or product behavior.
Re-run the application tests and builds after cleanup.

### 7. Apply application infrastructure safely

Authenticate to the target account, verify identity, initialize the exact
backend configuration, refresh the plan, and request confirmation for that plan.
Apply the saved plan only after confirmation.

After apply, capture non-sensitive outputs needed by GitHub and GitOps. Verify
that shared resources were reused and only planned application resources were
created or changed.

Do DEV first. Prepare PROD independently and stop before apply/release unless
the selected mode and confirmation include PROD.

### 8. Complete GitHub and GitOps wiring

Configure or instruct the user to configure GitHub `dev` and `prod`
environments using Terraform outputs and the platform contract. Keep secret
values in GitHub secrets or AWS Secrets Manager as specified by the workflow.

Publish repository changes only after the user approves the branch/commit set.
Then trigger the intended flow:

- DEV: push to the single configured `X.Y.Z` deployment branch;
- PROD: manual workflow from the matching `X.Y.Z` branch;
- rollback: manual workflow selecting the saved release version.

### 9. Verify the whole chain

Use the verification reference. A successful GitHub job alone is insufficient.
Verify GitHub Actions, ECR, frontend artifacts, versions pin, environment pin,
Argo child application, Liquibase PreSync Job, Deployment rollout, Pods,
Service, Ingress/ALB, Secrets Manager projection, database connectivity,
CloudFront, endpoint behavior, logs, and production metrics when enabled.

### 10. Handoff

Report:

- what was changed in each repository and AWS account;
- exact deployed image and Liquibase tags;
- Terraform plan/apply results;
- Argo application health and sync revision;
- frontend and API URLs;
- smoke-test results;
- manual actions still required;
- rollback target and known migration constraints;
- unverified items and why they remain unverified.

Use exactly one status from the authoritative enum in
`references/verification-and-recovery.md`. Only `VERIFIED` permits an
unqualified completion claim.
