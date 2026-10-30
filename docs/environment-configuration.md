# Environment configuration and promotion

## Environment model

| Environment | Where it runs | Object storage | Terraform |
|---|---|---|---|
| DEV | Docker Desktop Kubernetes | Separate, private DEV test bucket in the UAT account | Not used |
| UAT | EKS in the dedicated UAT AWS account | Private account-local S3 bucket | `environments/uat.tfvars` |
| PROD | EKS in the dedicated PROD AWS account | Separate private account-local S3 bucket | `environments/prod.tfvars` |

Use the same Helm chart and application source in each environment. Environment differences belong in tfvars, Helm values, deployment environment variables, and immutable image tags—not duplicated Terraform or Dockerfiles. The `*.example` files are templates; copy them to the ignored local filenames and replace every `REPLACE_...` or example CIDR before use.

## Configuration sources

Each tool reads a different configuration source:

- Docker Compose reads the repository-root `.env` for local builds and service settings.
- Terraform reads `terraform/environments/<environment>.tfvars`; `AWS_PROFILE` selects the AWS Identity Center/assumed-role profile and account.
- Helm reads the selected values file plus values passed by `scripts/k8s-deploy.sh`.
- Never put AWS access keys, JWT secrets, or other credentials in tracked values files. EKS uses IRSA; local DEV assumes a bucket-scoped role using short-lived credentials.

### Docker image names

`IMAGE_PREFIX` and `IMAGE_TAG` are configurable. Compose appends the service name to the prefix. For example, to build images for a Docker Hub account:

```bash
export IMAGE_PREFIX=docker.io/YOUR_DOCKERHUB_USER/streamingapp
export IMAGE_TAG="$(git rev-parse --short HEAD)"
docker compose build auth streaming admin chat frontend
```

This builds names such as `docker.io/YOUR_DOCKERHUB_USER/streamingapp-auth:<tag>`. To publish to Docker Hub, authenticate with `docker login` and run `docker compose push auth streaming admin chat frontend`. Do not put Docker Hub credentials in `.env`, Helm values, or Git.

For UAT/PROD, the AWS deployment helper builds the four backend images and frontend, then pushes immutable commit/time tags into that account's ECR repositories. The repository prefix defaults to `streamingapp-uat` or `streamingapp-prod`; override it with `ECR_REPOSITORY_PREFIX` only if Terraform was configured with a matching ECR naming scheme. The helper does not publish to Docker Hub.

## DEV: local Kubernetes and AWS S3

1. Enable Docker Desktop Kubernetes and use the `docker-desktop` context.
2. The UAT account must have the Terraform-created `local-dev` bucket and restricted role enabled. In the UAT tfvars, set `local_dev_access_enabled = true` and add the exact IAM Identity Center role ARN(s) that may assume the local role to `local_dev_access_principal_arns`. The operator permission set also needs `sts:AssumeRole` on that exact role.
3. Log in to the UAT account and export only non-secret identifiers/outputs:

   ```bash
   aws sso login --profile streamingapp-uat
   export AWS_PROFILE=streamingapp-uat
   export EXPECTED_AWS_ACCOUNT_ID=YOUR_UAT_ACCOUNT_ID
   export AWS_REGION=ap-south-1
   export AWS_S3_BUCKET="$(cd terraform && terraform output -raw local_dev_media_bucket_name)"
   export LOCAL_S3_ROLE_ARN="$(cd terraform && terraform output -raw local_dev_media_access_role_arn)"
   ```

4. Run from the repository root:

   ```bash
   ./scripts/k8s-deploy.sh local
   ```

   The helper builds app images, creates a local JWT Secret, assumes the restricted local S3 role for one hour, writes those temporary credentials to a Kubernetes Secret without printing them, deploys the app, restarts S3 clients with the fresh credentials, starts port-forwards, and checks the five app endpoints. After the session expires, refresh credentials without rebuilding images with `./scripts/k8s-deploy.sh refresh-local-aws-credentials`.
5. Register a user, grant that local user the admin role for testing, then sign in again and open `/admin`.
6. Upload a small video and thumbnail. The admin service stores objects in the isolated local-DEV bucket; MongoDB stores metadata. Browse and play the uploaded video to verify upload, thumbnail, and byte-range streaming.
7. View app resources with:

   ```bash
   kubectl -n streamingapp get deployments,pods,services,pvc
   kubectl -n streamingapp get secret
   ```

   Do not display or paste Secret contents. The local cluster holds temporary credentials only; the bucket remains private and is accessed through the AWS SDK in the backend.

This DEV test path does incur AWS S3 storage/request charges. The Terraform-created DEV bucket is separate from the UAT application bucket, encrypted, versioned, and public-access-blocked. The local assumed role is restricted to that DEV bucket. Run `./scripts/k8s-deploy.sh status` to check the app and `./scripts/k8s-deploy.sh stop-local` to stop only the port-forwards.

For Docker Compose-only tests, leave `AWS_S3_ENDPOINT` and `AWS_S3_BUCKET` unset unless you separately configure a bucket and short-lived AWS session credentials. The Kubernetes helper is the supported local AWS S3 path.

## UAT and PROD: separate AWS accounts

Create an IAM Identity Center permission set and assign the appropriate team group in each AWS account. Keep UAT deployers separate from production approvers/operators. Do not share one IAM user or static access key between teams. Confirm the selected profile/account before each Terraform or deploy operation:

```bash
aws sso login --profile streamingapp-uat
aws sts get-caller-identity --profile streamingapp-uat
```

Copy and edit the per-environment input templates:

```bash
cp terraform/environments/uat.tfvars.example terraform/environments/uat.tfvars
cp terraform/backend/uat.s3.tfbackend.example terraform/backend/uat.s3.tfbackend
cp helm/streamingapp/values-uat.yaml.example helm/streamingapp/values-uat.yaml
```

Use the equivalent `prod` templates only in the dedicated production account. Set the actual trusted EKS API CIDR, region, account/profile, public HTTPS origin, S3 bucket output, and IRSA role output. `terraform/environments/*.tfvars` and the non-example local Helm values are ignored by Git.

Terraform names clusters as `<project>-<environment>-eks`, and creates that environment's VPC, security group, EKS managed node group, OIDC provider, ALB Controller role, immutable ECR repositories, private encrypted/versioned media bucket, and a least-privilege app IRSA role. When enabled in UAT only, it also creates an isolated DEV test bucket and a separate role for local one-hour sessions. EKS managed node groups supply the EC2 instances; a separate EC2 module is not needed for this design. VPC, security group, and IAM resources are already part of the root configuration; they have not been extracted into reusable child modules.

### Bootstrap the Terraform state backend (once per AWS account)

The state bucket and DynamoDB lock table are separate bootstrap resources; they are not created by this Terraform configuration. Create them in each environment's account, using a distinct bucket name, and ensure the bucket has versioning, encryption, and all four S3 Block Public Access settings enabled. Keep the lock table in the same region as the backend bucket. These resources must exist before `terraform init`.

For example, after selecting the UAT profile and replacing the account ID in the bucket name:

```bash
export AWS_PROFILE=streamingapp-uat
export AWS_REGION=ap-south-1
export TF_STATE_BUCKET="streamingapp-uat-tfstate-YOUR_UAT_ACCOUNT_ID"
aws sso login --profile "$AWS_PROFILE"
aws sts get-caller-identity --profile "$AWS_PROFILE"
aws s3api create-bucket --profile "$AWS_PROFILE" --region "$AWS_REGION" \
  --bucket "$TF_STATE_BUCKET" \
  --create-bucket-configuration "LocationConstraint=$AWS_REGION"
aws s3api put-public-access-block --profile "$AWS_PROFILE" \
  --bucket "$TF_STATE_BUCKET" \
  --public-access-block-configuration \
  'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
aws s3api put-bucket-versioning --profile "$AWS_PROFILE" \
  --bucket "$TF_STATE_BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --profile "$AWS_PROFILE" \
  --bucket "$TF_STATE_BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws dynamodb create-table --profile "$AWS_PROFILE" --region "$AWS_REGION" \
  --table-name streamingapp-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Repeat with the dedicated PROD profile and a different bucket name. The two accounts may each use a table named `streamingapp-terraform-locks`; they are isolated by account. Grant team operators only the required bucket state-object and lock-table permissions. Copy the environment-specific backend example, replace the placeholder bucket, and initialize before planning:

```bash
cp terraform/backend/uat.s3.tfbackend.example terraform/backend/uat.s3.tfbackend
# Edit the bucket to match the UAT account's bootstrap bucket.
cd terraform
AWS_PROFILE=streamingapp-uat terraform init -reconfigure \
  -backend-config=backend/uat.s3.tfbackend
AWS_PROFILE=streamingapp-uat terraform plan -var-file=environments/uat.tfvars
```

For PROD, use `prod.s3.tfbackend`, `streamingapp-prod`, and `environments/prod.tfvars`. Confirm the selected AWS account before every operation. Do not copy backend config files or Terraform state between accounts; backend config files are gitignored, and the media S3 buckets are unrelated to Terraform state. No AWS resources have been created by this guide/change.

Review plans independently in each account; never run one environment's apply while authenticated to the other account:

```bash
cd terraform
aws sso login --profile streamingapp-uat
AWS_PROFILE=streamingapp-uat terraform plan -var-file=environments/uat.tfvars
```

Apply only after the account, plan, trusted CIDR, cost, and approval have been checked. The configuration blocks public bucket access, enables server-side encryption and versioning, and restricts each app/local role to its own bucket's list/get/put/delete operations. Buckets are not force-deleted; remove retained object versions deliberately before destroying an environment.

After an approved Terraform apply and required EKS add-ons are ready, export values from that same environment/account and deploy:

```bash
export DEPLOY_ENV=uat
export PROJECT_NAME=streamingapp
export AWS_PROFILE=streamingapp-uat
export EXPECTED_AWS_ACCOUNT_ID=YOUR_UAT_ACCOUNT_ID
export AWS_REGION=ap-south-1
export EKS_CLUSTER_NAME=streamingapp-uat-eks
export TRUSTED_EKS_API_CIDR=YOUR_TRUSTED_PUBLIC_IP/32
export AWS_S3_BUCKET="$(cd terraform && terraform output -raw media_bucket_name)"
export APP_MEDIA_ROLE_ARN="$(cd terraform && terraform output -raw app_media_access_role_arn)"
export HELM_VALUES_FILE=helm/streamingapp/values-uat.yaml
./scripts/k8s-deploy.sh aws
```

For PROD, use `DEPLOY_ENV=prod`, the production profile/account ID, production values file, and production Terraform outputs. The helper verifies the AWS account and trusted EKS API CIDR, checks required ECR repositories and cluster prerequisites, and prompts for the literal `deploy` before it pushes images and changes the release. It never runs `terraform apply`. Do not use the example HTTP ALB configuration for a public production service; configure an ACM certificate, HTTPS listener/redirect, DNS, secure secret management, and approved production values before rollout.

## Infrastructure and remaining work

Terraform already provisions the basic VPC, EKS control-plane/node IAM roles, cluster security group, managed EC2 nodes, ECR, and ALB Controller IRSA. This change adds the per-environment S3 bucket and app IRSA role. The EKS control-plane log types are enabled, but application metrics, dashboards, alerting, HPA, and full CloudWatch Container Insights/Prometheus configuration are not implemented; add those as the monitoring work in Milestone 3.

This is not yet a production-ready platform. The current EKS node group uses public subnets; production should move worker nodes to private subnets and review NAT/endpoints/costs. Production also needs a managed MongoDB service/backup and restore plan, TLS/DNS, workload and pod security hardening, and a tested backup/rollback strategy. Review these gaps and costs before applying in either AWS account.
