# Terraform and Helm deployment guide

This repository includes a minimal Terraform configuration for provisioning the AWS EKS foundation and a Helm chart for deploying StreamingApp microservices into Kubernetes.

## Terraform

### Prerequisites

- AWS CLI configured for the target account/profile via IAM Identity Center or a role-based credential flow
- Terraform 1.5 or newer
- IAM permissions that allow VPC, EKS, IAM role, and ECR creation in the selected account/region

### Local validation completed

The project has been validated locally without applying AWS changes:

```bash
cd terraform
terraform init
terraform fmt
terraform validate
```

This succeeds with the current configuration and confirms the Terraform files are syntactically valid.

### Production apply workflow

```bash
cd terraform
terraform plan
terraform apply
```

The configuration provisions:

- VPC, public subnets, internet gateway, and route tables
- EKS cluster and managed node group
- IAM roles for the cluster, node group, and AWS Load Balancer Controller
- ECR repositories for the auth, streaming, admin, chat, and frontend images

Important:

- Do not commit Terraform state, kubeconfig files, or generated AWS credentials.
- The AWS account/role must be configured before any `terraform apply` or cluster deployment.
- The current environment does not have AWS credentials configured, so the EKS cluster has not been created or validated in AWS yet.

## Helm

### Local validation completed

```bash
export PATH="$HOME/.local/bin:$PATH"
helm lint ./helm/streamingapp
helm template ./helm/streamingapp
```

The chart lint and template render succeeded locally. The rendered output confirms the workloads and ingress resources are generated as expected.

### Release install example

```bash
helm upgrade --install streamingapp ./helm/streamingapp \
  --namespace streamingapp \
  --create-namespace
```

The chart deploys:

- MongoDB persistence for local/dev use
- authService, streamingService, adminService, chatService, and frontend
- An ingress that routes `/api`, `/api/streaming`, `/api/admin`, `/api/chat`, `/socket.io`, and `/` to the correct workloads

### Runtime configuration notes

- Replace the placeholder ECR image references and example URLs in `helm/streamingapp/values.yaml` with the final ECR tags and ALB host information.
- Frontend URLs are static at build time; the React bundle should receive the final API and Socket URLs during the image build, not after deployment.
- Store secrets in Kubernetes Secrets or a managed secret store rather than plain chart values.

## Deployment status

Current validation status:

- Terraform: validated locally (`terraform validate` passed)
- Helm: lint/template passed locally (`helm lint` and `helm template` passed)
- AWS identity: not configured in this environment (`aws sts get-caller-identity` returned `NoCredentials`)
- EKS apply/endpoint verification: pending AWS account access and owner approval

This means the repository is ready for a controlled AWS deployment once credentials and permissions are available, but it is not yet deployed or verified against a live EKS cluster.

