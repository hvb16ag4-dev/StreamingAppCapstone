# Terraform and Helm deployment guide

This repository contains a temporary-validation Terraform foundation and Helm chart for deploying StreamingApp on Amazon EKS. Local syntax/render checks pass; this is not evidence of a live AWS deployment.

## Terraform

### Prerequisites

- AWS CLI configured for the approved account/profile through IAM Identity Center (recommended) or a short-lived assumed role
- Terraform 1.5 or newer
- A budget alert and owner approval for the expected EKS, EC2, EBS, and load-balancer costs
- A trusted operator/CI egress IPv4 CIDR for the EKS public API endpoint

Do not create a long-lived `terraform_user` IAM user or access key. An AWS administrator should create an IAM Identity Center permission set, assign it to the operator (directly or through a team group), and grant only the needed VPC, EKS, ECR, and IAM actions. The permission set must allow `iam:PassRole` only for the specific EKS cluster and node roles created by this configuration, with the appropriate AWS service conditions. Terraform also creates the OIDC provider and the AWS Load Balancer Controller IAM role/policy. Review the exact actions and permissions in `terraform/` before provisioning.

The human/deployment permission set is separate from the EKS cluster role, node role, and in-cluster AWS Load Balancer Controller role. Do not attach application deployment permissions to a general-purpose IAM user. Jenkins, if used later, should use a separate short-lived role/OIDC integration.

## Local test before AWS

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

All five HTTP checks returned success on 2026-10-28. The frontend is at `http://localhost:3000`. Test registration/login, catalogue browsing, and chat from two browser sessions. S3 upload/playback is not expected to work until the bucket and workload permissions are configured. `docker compose down` stops the local stack; do not add `-v` unless you intend to delete its MongoDB data.

### Local validation completed

The project has been validated locally without applying AWS changes:

```bash
cd terraform
terraform init
terraform fmt -check
terraform validate
```

These checks do not contact AWS or create resources. Before planning, configure AWS SSO and verify the identity with `aws sts get-caller-identity`.

### Plan and apply

```bash
cd terraform
terraform plan \
  -var='cluster_public_access_cidrs=["YOUR_TRUSTED_PUBLIC_IP/32"]'
terraform apply \
  -var='cluster_public_access_cidrs=["YOUR_TRUSTED_PUBLIC_IP/32"]'
```

Replace the example CIDR with the trusted operator or deployment runner's actual stable egress CIDR. The EKS endpoint rejects a world-open CIDR. Review the full plan and cost estimate before approving `apply`.

The configuration provisions:

- VPC, public subnets, internet gateway, and route tables
- EKS cluster and managed node group
- IAM roles for the cluster, node group, and AWS Load Balancer Controller
- ECR repositories for the auth, streaming, admin, chat, and frontend images

The Kubernetes version default is `1.37`, the latest version listed in standard support by the [EKS Kubernetes version lifecycle documentation](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) at the time of this update. Recheck supported versions before applying.

Important:

- Do not commit Terraform state, kubeconfig files, or generated AWS credentials.
- AWS CLI authentication currently succeeds, but it is using IAM-user credentials rather than IAM Identity Center. Migrate to the approved short-lived SSO/assumed-role flow before provisioning; do not create another long-lived `terraform_user` access key.
- No AWS plan or apply has been run, and the EKS cluster has not been created or validated in AWS.
- Supply the actual trusted operator/CI egress CIDR before planning; no CIDR is guessed or committed in this repository.
- The Terraform backend is local by default. For team use, agree on a secured remote S3 backend with locking before `terraform init`; do not move or replace state casually.
- The bundled controller policy is sourced from the [AWS Load Balancer Controller upstream policy](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json). Review/update it when upgrading the controller.

## Helm

### Local validation completed

```bash
export PATH="$HOME/.local/bin:$PATH"
helm lint ./helm/streamingapp
helm template ./helm/streamingapp
```

The chart lint and template render succeeded locally. The chart deploys one MongoDB instance, the four backend services, the frontend, and an ALB ingress. It expects the AWS Load Balancer Controller to be installed in the cluster and the matching IAM role from Terraform to be annotated on its Kubernetes service account. Install the controller using the official AWS instructions before relying on the Ingress.

### Prepare secrets and install

```bash
aws eks update-kubeconfig --region ap-south-1 --name streamingapp-eks
kubectl create namespace streamingapp
kubectl -n streamingapp create secret generic streamingapp-runtime \
  --from-literal=jwt-secret="$(openssl rand -hex 32)"

helm upgrade --install streamingapp ./helm/streamingapp \
  --namespace streamingapp \
  --set-string services.auth.image=ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-auth:TAG \
  --set-string services.streaming.image=ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-streaming:TAG \
  --set-string services.admin.image=ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-admin:TAG \
  --set-string services.chat.image=ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-chat:TAG \
  --set-string services.frontend.image=ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/streamingapp-frontend:TAG
```

Do not place the JWT value in Helm values, source control, or terminal logs. The chart references the pre-created Kubernetes Secret named by `secrets.existingSecret` (`streamingapp-runtime` by default).

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

The current Terraform configuration does not create an S3 bucket or an application-specific IAM role/policy for S3. Admin uploads and S3-backed playback therefore remain unconfigured until the owner selects the bucket and the app's least-privilege S3 access is added. Do not copy AWS access keys into Helm values; prefer workload identity/IRSA.

The chart's single MongoDB/PVC setup is for temporary validation only. Use a managed database and proper backup/retention design for production. The public ALB is also billable; destroy temporary resources only after evidence and data retention are confirmed.

## Deployment status

Current validation status:

- Terraform: validated locally (`terraform validate` passed)
- Helm: lint/template passed locally (`helm lint` and `helm template` passed)
- Local application stack: all five app images built; `mongo:6` pulled; backend health checks and frontend returned HTTP 200
- AWS CLI identity: authenticated; the current credential type is an IAM user, so SSO/role-based access should be configured before provisioning
- EKS apply/endpoint verification: pending AWS account access and owner approval

This means the repository is locally validated but not yet deployed or verified against a live EKS cluster. Confirm the permission set, budget, public API CIDR, and reviewed plan before applying.
