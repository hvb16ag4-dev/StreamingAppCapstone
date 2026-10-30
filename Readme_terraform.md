# Terraform and Helm deployment guide

This repository contains Terraform/Helm configuration for local DEV and separate-account UAT/PROD EKS environments. Configuration and safe deployment steps are in [docs/environment-configuration.md](./docs/environment-configuration.md). Local syntax/render checks do not imply that AWS resources have been created.

## Terraform

### Prerequisites

- AWS CLI configured for the approved account/profile through IAM Identity Center (recommended) or a short-lived assumed role
- Terraform 1.5 or newer
- Separate approved IAM Identity Center profiles for the UAT and PROD AWS accounts
- A budget alert and owner approval for expected EKS, EC2, EBS, S3, and load-balancer costs
- A trusted operator/CI egress IPv4 CIDR for the EKS public API endpoint

Do not create a long-lived `terraform_user` IAM user or access key. An AWS administrator should create an IAM Identity Center permission set, assign it to the operator (directly or through a team group), and grant only the needed VPC, EKS, ECR, and IAM actions. The permission set must allow `iam:PassRole` only for the specific EKS cluster and node roles created by this configuration, with the appropriate AWS service conditions. Terraform also creates the OIDC provider and the AWS Load Balancer Controller IAM role/policy. Review the exact actions and permissions in `terraform/` before provisioning.

The human/deployment permission set is separate from the EKS cluster role, node role, AWS Load Balancer Controller role, and app media-access role. The app accesses only its environment's S3 bucket through IRSA; it does not receive long-lived AWS credentials. Jenkins, if used later, should use a separate short-lived role/OIDC integration.

## Local test before AWS

For the local Kubernetes + UAT-account S3 test flow (Docker Desktop or Minikube), image configuration, environment variables, commands, and cleanup, see [docs/local-kubernetes-testing.md](./docs/local-kubernetes-testing.md).
For environment separation, Docker Hub/ECR image configuration, AWS account setup, Terraform variables, and promotion steps, see [docs/environment-configuration.md](./docs/environment-configuration.md).
The one-command local deployment/recovery helper is `./scripts/k8s-deploy.sh local`; for AWS, use `./scripts/k8s-deploy.sh aws` only after the cluster prerequisites in that guide are satisfied.

The backend images are not checked into Git or automatically present in Docker. Build them locally from the Compose configuration:

```bash
docker compose build auth streaming admin chat frontend
docker compose pull mongo
docker image ls
docker compose up -d
docker compose ps
```

Compose builds the five application images and pulls the public `mongo:6` image. MongoDB does not need a custom application image or an ECR repository for this temporary setup. The Helm chart also pulls `mongo:6` from Docker Hub and stores data on its PVC. Use a managed database rather than this single MongoDB pod for production.

Check the local services:

```bash
curl -fsS http://localhost:3001/health
curl -fsS http://localhost:3002/api/health
curl -fsS http://localhost:3003/api/health
curl -fsS http://localhost:3004/api/health
curl -I http://localhost:3000
```

All five HTTP checks passed in earlier local runs. The new S3-backed local configuration requires the UAT bucket and role to be provisioned first; see [docs/local-kubernetes-testing.md](./docs/local-kubernetes-testing.md). The frontend is at `http://localhost:3000` while its port-forward is active. Test registration/login, chat, video upload, and playback. `docker compose down` stops the Compose stack; do not add `-v` unless you intend to delete its MongoDB data.

### Local validation completed

The Terraform syntax can be checked locally without applying AWS changes:

```bash
cd terraform
terraform init -backend=false
terraform fmt -check
terraform validate
```

These checks do not create resources. For any plan or apply, first bootstrap the remote state bucket and lock table in the target account as described in [docs/environment-configuration.md](./docs/environment-configuration.md), then initialize with that environment's backend config. Before planning, configure the correct account's AWS SSO profile and verify it with `aws sts get-caller-identity --profile <profile>`.

### Plan and apply

Use `terraform/environments/uat.tfvars.example` and `prod.tfvars.example` as separate environment inputs. Replace the documentation CIDR before planning. DEV is local and is not provisioned with Terraform. UAT and PROD require separate remote state buckets and keys; the S3 backend is configured per invocation using an ignored `.tfbackend` file.

The configuration provisions:

- VPC, public subnets, internet gateway, and route tables
- EKS cluster and managed node group
- IAM roles for the cluster, node group, AWS Load Balancer Controller, and app S3 access
- Immutable ECR repositories for each environment's auth, streaming, admin, chat, and frontend images
- A private, encrypted, versioned media S3 bucket per account/environment

The Kubernetes version default is `1.37`, the latest version listed in standard support by the [EKS Kubernetes version lifecycle documentation](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) at the time of this update. Recheck supported versions before applying.

Important:

- Do not commit Terraform state, kubeconfig files, or generated AWS credentials.
- Verify the active AWS identity before provisioning. If the CLI uses an IAM user, migrate to the approved short-lived SSO/assumed-role flow; do not create a long-lived `terraform_user` access key.
- No AWS plan or apply has been run, and the EKS cluster has not been created or validated in AWS.
- Supply the actual trusted operator/CI egress CIDR before planning; no CIDR is guessed or committed in this repository.
- The Terraform S3 backend requires a pre-created, versioned, public-access-blocked state bucket and a DynamoDB lock table in each target account. Backend example files contain placeholders and must be copied/edited before initialization.
- Control-plane log types are enabled, but application metrics/dashboards/alerts and CloudWatch Container Insights/Prometheus configuration are not yet implemented.
- EKS worker nodes currently use public subnets. Review private nodes/NAT/endpoints, managed MongoDB and backups, TLS/DNS, and monitoring before any production apply.
- The bundled controller policy is sourced from the [AWS Load Balancer Controller upstream policy](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json). Review/update it when upgrading the controller.

## Helm

### Local validation completed

```bash
export PATH="$HOME/.local/bin:$PATH"
helm lint ./helm/streamingapp
helm template ./helm/streamingapp
```

The chart includes MongoDB, the four backend services, the frontend, and an ALB ingress. It creates an app service account; in EKS, annotate it with that account's Terraform `app_media_access_role_arn` output. Install the AWS Load Balancer Controller and storage driver in EKS before relying on Ingress or PVCs.

### Deploy

Use `./scripts/k8s-deploy.sh local` for local DEV, or follow the account/profile-specific UAT/PROD procedure in [docs/environment-configuration.md](./docs/environment-configuration.md). The AWS helper requires this environment's ECR prefix, media bucket, and IRSA role outputs; it uses a unique immutable image tag and does not run Terraform apply.

The frontend image is a static React build. Its Dockerfile defaults API and Socket.IO URLs to same-origin paths (`/api`, `/api/admin`, `/api/chat`, `/`), and those values must be present at image build time; setting React environment variables on a running Nginx container does not rewrite the bundle. Override Docker build arguments only when using a different routing design.

After the ALB has an address, configure the backend `CLIENT_URLS` chart values to the exact public origin, for example `http://<ALB-DNS-name>`, and upgrade the release. Repeat for auth, streaming, admin, and chat so CORS allows the actual site. For a stable hostname, set `ingress.host` and the matching `CLIENT_URLS` value. The chart currently defaults these origins to localhost for local development; update them before relying on public API calls.

For the generated ALB DNS name, the follow-up upgrade can use:

```bash
helm upgrade streamingapp ./helm/streamingapp \
  --namespace streamingapp \
  --set-string services.auth.env.CLIENT_URLS=http://your-alb-dns-name.elb.amazonaws.com \
  --set-string services.streaming.env.CLIENT_URLS=http://your-alb-dns-name.elb.amazonaws.com \
  --set-string services.admin.env.CLIENT_URLS=http://your-alb-dns-name.elb.amazonaws.com \
  --set-string services.chat.env.CLIENT_URLS=http://your-alb-dns-name.elb.amazonaws.com
```

The local Kubernetes profile accesses an isolated S3 bucket in the UAT account using a one-hour role session; the Terraform UAT configuration creates that bucket only when local DEV access is explicitly enabled. The AWS Terraform root also creates a separate UAT application bucket and a separate PROD bucket with public access blocked and least-privilege app roles. The chart's single MongoDB/PVC setup remains for temporary validation only. Use a managed database and proper backup/retention design for production.

## Deployment status

Current validation status:

- Terraform: syntax formatting/checks are local-only; no AWS plan/apply has been run
- Helm: base and local values lint/template passed locally
- Local application stack: all five app images built; `mongo:6` pulled; backend health checks and frontend returned HTTP 200
- AWS account resources: not created; separate UAT and PROD account profiles, state backends, CIDRs, cost approval, and production hardening are pending

This means the repository is locally validated but not yet deployed or verified against a live EKS cluster. Confirm the permission set, budget, public API CIDR, and reviewed plan before applying.
