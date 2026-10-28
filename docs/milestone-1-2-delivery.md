# Milestones 1 and 2: Delivery Plan and Evidence

This document tracks the implementation and verification of the AWS infrastructure and EKS application deployment milestones. Update the status, decisions, test results, challenges, fixes, and evidence links as work is completed. Do not mark a step complete based only on configuration existing in the repository; record validation or deployed evidence.

## Scope and current baseline

### Milestone 1 — Terraform provisions AWS EKS infrastructure

**Target outcome:** A repeatable Terraform configuration provisions the AWS resources required for the StreamingApp EKS environment, with documented setup, outputs, validation, and cleanup.

**Repository baseline:** No Terraform configuration (`.tf` or `.tfvars`) was found at the start of this plan. `Readme_terraform.md` is a placeholder.

### Milestone 2 — Docker and Helm deploy StreamingApp to EKS using Ingress

**Target outcome:** The application images are built and available from ECR; Helm installs the services into EKS; users reach the frontend and required API/WebSocket endpoints through Ingress; and deployment health is verified.

**Repository baseline:** Dockerfiles, Kubernetes manifests, a Helm chart, and an EKS deployment stage in Jenkins exist. The chart currently has no Ingress template. Frontend URLs are Docker build-time values, while chart ConfigMap values do not change the already-built frontend bundle. Configuration, namespace creation order, chart rendering, and image build contexts require validation before the deployment can be considered working.

## Decisions and inputs needed

Record each decision here before implementing the affected work. Never put AWS credentials, tokens, private keys, or secret values in this document, Git, screenshots, or chat.

| Decision/input | Current value | Needed for |
|---|---|---|
| AWS account to deploy into | **Needed from owner** (share account alias/ID only if useful; never credentials) | Resource ownership and cost estimate |
| AWS region | `ap-south-1` (Mumbai), confirmed by owner | Terraform, ECR, EKS, Ingress |
| AWS access method | IAM Identity Center is available; use a dedicated permission set and assigned role, not a long-lived IAM user access key | Secure Terraform and deployment access |
| Deployment target | Create a new dedicated VPC and EKS cluster; no existing VPC/EKS is available | Terraform scope and resource import/avoidance |
| Cost constraints and allowed node types/capacity | Minimize cost; validate locally first; use AWS only for temporary final verification, then stop/destroy resources | EKS sizing and safe testing/cleanup |
| DNS/domain and TLS certificate | Use the generated ALB hostname for temporary verification; defer custom domain/TLS to production testing | Ingress host rules and frontend URLs |
| MongoDB placement | Use the existing single-instance in-cluster MongoDB/PVC for temporary verification; data may be destroyed during teardown. Document a managed database option for production. | Persistence, cost, credentials, and Helm resources |
| Existing S3 bucket/CDN | Create a temporary S3 bucket with Terraform for the test; no CDN unless required by validation. Delete bucket contents and bucket during approved teardown. | Streaming/admin configuration and IAM permissions |
| Terraform state storage | Recommend remote S3 state with locking; confirm whether a state bucket/lock mechanism already exists | Safe collaboration and repeatable Terraform runs |
| Image/deployment ownership | Current Jenkinsfile builds and pushes images; confirm whether Jenkins remains the deployment runner or a local operator runs Helm | CI credentials and deployment procedure |

Use AWS IAM Identity Center with a dedicated permission set and assigned group/user for Terraform and deployment. Do not create a long-lived `terraform_user` access key when Identity Center is available. The account administrator should grant only the actions needed for the approved resources and `iam:PassRole` to the specific EKS roles. Do not paste credentials into chat or commit them. The owner should configure local AWS CLI SSO access and any Jenkins role directly in their trusted environments.

### Cost and lifecycle policy

- Prefer local Docker/Helm rendering and other local checks before provisioning AWS resources.
- Treat the EKS environment as temporary evidence infrastructure: deploy only for final AWS verification, capture redacted evidence, then destroy resources that incur charges.
- Add a budget alert before provisioning. EKS control-plane, load-balancer, NAT/networking, and storage costs may apply even when application traffic is low; AWS Free Tier should not be assumed to cover a complete EKS environment.
- Keep Terraform inputs reusable and documented so the environment can be provisioned again. Separate temporary test sizing from any later production sizing; do not describe a single-node cost-minimized test cluster as highly available production infrastructure.
- Before destroy, confirm the owner has saved required evidence and that no data needs to be retained. Verify cost-incurring resources are removed after cleanup.

## Work plan and completion criteria

### Task 0 — Confirm design and secure prerequisites

- [ ] Confirm the decisions and inputs in the table above.
- [ ] Confirm the AWS identity/role has only the required permissions and is configured locally or in Jenkins.
- [ ] Install/configure required tools in the same WSL environment used for the repository: Terraform, AWS CLI, Docker, kubectl, and Helm.
- [ ] Configure AWS CLI with IAM Identity Center and verify the selected profile/account using `aws sts get-caller-identity`.
- [ ] Configure a budget alert and agree on a cleanup window for temporary EKS resources.
- [ ] Use the generated ALB hostname for temporary verification; revisit the owner's domain and TLS certificate during production testing.

**Evidence to capture:** redacted `aws sts get-caller-identity` output (account ID may be masked in public documents), tool versions, and approved design decisions.

### Task 1 — Implement and validate Terraform (Milestone 1)

- [ ] Add Terraform modules/configuration for the agreed network, EKS control plane, managed node capacity, IAM roles/policies, cluster access, and required ECR repositories.
- [ ] Include the IAM/OIDC permissions needed by the AWS Load Balancer Controller (or document an approved alternative).
- [ ] Choose and document remote state, locking, provider/version constraints, inputs, outputs, and tagging.
- [ ] Keep secrets and generated state out of version control; add ignore rules where needed.
- [ ] Document prerequisites, initialization, plan review, apply, outputs, and destroy/retention steps.
- [ ] Run formatting, initialization, validation, and a reviewed plan. Do not apply until the owner approves the plan and expected cost.
- [ ] Apply only to the approved account/region; verify EKS endpoint, node readiness, and ECR repositories.

**Completion criteria:** A clean Terraform validation and reviewed plan; successfully provisioned infrastructure in the approved AWS account; EKS nodes Ready; documented outputs and cleanup; no credentials or Terraform state committed.

**Evidence to capture:** redacted Terraform version/validation result and plan summary; AWS console or CLI evidence of EKS and node-group health; resource names/region; screenshots saved under `docs/evidence/` with sensitive identifiers redacted as appropriate.

### Task 2 — Make container images and runtime configuration deployable

- [ ] Verify each Docker build context and Dockerfile builds the intended image from the repository root.
- [ ] Build all five application images: auth, streaming, admin, chat, and frontend.
- [ ] Confirm image names/tags match the ECR repositories and Helm values used by the deployment pipeline.
- [ ] Supply frontend API/socket URLs at image build time for the selected Ingress URL design; do not expect a runtime ConfigMap to rewrite a static React build.
- [ ] Configure service-to-service MongoDB URI, public origins, S3/CDN settings, and secrets for Kubernetes.
- [ ] Ensure secrets are created only after the namespace exists and are sourced from an approved secret store/credential binding; never store secret values in Helm values or ConfigMaps.
- [ ] Review MongoDB persistence and backup/retention expectations for the selected database option.

**Completion criteria:** Images build successfully, can be pushed/pulled from ECR by the cluster, and application configuration resolves to the intended service endpoints rather than `localhost`.

**Evidence to capture:** redacted Docker build/push output and ECR image tags; configuration key names (not secret values); successful frontend/API endpoint checks after deployment.

### Task 3 — Complete Helm and Ingress deployment (Milestone 2)

- [ ] Make chart namespace and resource names consistent and configurable where appropriate.
- [ ] Add and configure Ingress routing for the frontend, API services, and chat WebSocket traffic. Confirm controller, DNS, TLS, and path/host strategy.
- [ ] Resolve duplicate/conflicting standalone `k8s/` and Helm configuration sources or document which is authoritative.
- [ ] Render the chart with the exact production-like values and inspect the rendered resource names, namespaces, images, environment references, and service selectors.
- [ ] Add appropriate readiness/liveness probes and resource requests/limits for application containers.
- [ ] Ensure the database PVC has a supported StorageClass and the expected persistence behavior.
- [ ] Install/upgrade with Helm in the target namespace; check rollout status and pod/service/PVC/Ingress health.
- [ ] Test the public frontend, authentication, catalogue/streaming API, admin API where applicable, and chat WebSocket path.
- [ ] Verify rollback procedure using Helm revision history; only exercise rollback where safe for data.

**Completion criteria:** Helm lint/render succeeds; every expected pod is Ready; persistent storage binds if in scope; Ingress obtains an address and routes requests correctly; application checks pass over the public endpoint; rollback instructions are verified.

**Evidence to capture:** chart lint/template output; redacted `kubectl get pods,svc,pvc,ingress -n <namespace>`; rollout status; Ingress address and HTTP/WebSocket smoke-test results; Helm release history and rollback result if exercised.

### Task 4 — Documentation, final verification, and delivery

- [ ] Update the project README and `Readme_terraform.md` with verified setup and deployment steps.
- [ ] Record encountered challenges and the actual fixes (not anticipated issues as though they happened).
- [ ] Add test commands, date, environment, result, and any known limitations.
- [ ] Add screenshots/results under `docs/evidence/`; redact credentials, tokens, private endpoints, and personal data.
- [ ] Verify Git status, ignore rules, and staged diff before each commit.
- [ ] Commit and push each completed task/checkpoint to the agreed branch; do not bundle unrelated or unverified work into a completion commit.

## Validation record

Update this table with actual command output summaries and dates. Do not record a pass unless the command was run successfully.

| Date | Milestone/task | Command or check | Result | Evidence |
|---|---|---|---|---|
| Not run | Baseline | Terraform files present | No `.tf`/`.tfvars` files found | Repository inspection |
| Not run | Milestone 2 | Helm chart includes Ingress | No Ingress template found | Repository inspection |
| Not run | Terraform | `terraform fmt -check` / `terraform validate` | Pending tooling/configuration | — |
| Not run | Helm | `helm lint` / `helm template` | Pending tooling/configuration | — |
| Not run | EKS deploy | Rollout and endpoint smoke tests | Pending infrastructure | — |

## Challenges and fixes

Add dated entries when a challenge is observed and resolved. Include the failing symptom, root cause, fix, and verification.

| Date | Challenge/symptom | Root cause | Fix | Verification |
|---|---|---|---|---|
| Pending deployment | No Terraform source currently exists | Infrastructure has not yet been codified in the repository | Planned in Task 1 | Pending |
| Pending deployment | Helm chart has no Ingress resource | Ingress routing/controller integration is not yet configured in the chart | Planned in Task 3 | Pending |

## Git checkpoint policy

Work on the local `feature_terraform` branch. Use one focused commit for each completed task or logical checkpoint, for example:

1. `docs: add milestone 1 and 2 delivery plan`
2. `infra: provision EKS foundation with Terraform`
3. `deploy: add Helm ingress and EKS application configuration`
4. `docs: record deployment validation and evidence`

Before each commit, inspect `git status` and `git diff --cached`, ensure secrets/state/evidence with sensitive information are excluded or redacted, and include the required co-author trailer. Do not push from this environment: the owner will push `feature_terraform` from their console. After each meaningful checkpoint, report the commit hash and whether it is ready for the owner to push.
