# GitHub Actions CI/CD setup

This guide covers the AWS and GitHub prerequisites for StreamingApp CI/CD. The dedicated UAT self-hosted runner is configured; GitHub Actions workflows and production setup are still pending. Keep UAT and production isolated.

## Recommended workflow and branch model

Use one GitHub Actions setup in this repository, split by purpose:

1. **Pull request validation:** run application checks, Docker builds, Helm lint/template checks, and Terraform format/validation.
2. **Terraform:** create a reviewed UAT plan for pull requests and apply UAT only after a merge to `main`.
3. **Application release:** build and publish immutable images to UAT ECR and deploy to UAT EKS after a merge to `main`.
4. **Production:** add a separately approved release job only after production AWS is ready.

Do not grant AWS credentials to untrusted pull request code. A plan that reads real Terraform state should run only in a protected GitHub Environment after an authorized reviewer approves it. Never use `pull_request_target` to check out and execute pull request code with AWS access.

Create short-lived feature branches from `feature_terraform` for this work, then merge through reviewed pull requests. Protect `main` with required pull requests and passing checks. There is no need for separate long-lived “DevOps” and “app release” branches.

The GitHub Actions workflows are not configured yet. The dedicated UAT self-hosted runner is now configured and reported **Idle** in GitHub; use the manual UAT deploy instructions in [environment-configuration.md](./environment-configuration.md) to validate the AWS deployment before implementing automation.

## 1. Confirm the AWS account and region

The AWS account ID is an identifier, not a password. It may be kept as a GitHub Environment variable; it does not need to be committed to this repository. Confirm the current account before creating any resources:

```bash
aws sts get-caller-identity --profile YOUR_UAT_PROFILE --query '{Account:Account,Arn:Arn}' --output json
```

Use the UAT account and `ap-south-1` for the steps below. Do not share or commit AWS access keys, SSO tokens, Terraform state, or kubeconfig files.

## 2. Create the UAT Terraform state backend

The Terraform backend examples expect an S3 bucket and DynamoDB lock table, which are bootstrap resources and are not created by the Terraform root. Create them once in the UAT account before running Terraform. Choose a globally unique bucket name; do not reuse the media bucket.

```bash
export AWS_PROFILE=YOUR_UAT_PROFILE
export AWS_REGION=ap-south-1
export TF_STATE_BUCKET=YOUR_GLOBALLY_UNIQUE_UAT_STATE_BUCKET
export TF_LOCK_TABLE=streamingapp-terraform-locks

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
  --table-name "$TF_LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Wait until DynamoDB reports the table as `ACTIVE`:

```bash
aws dynamodb describe-table --profile "$AWS_PROFILE" --region "$AWS_REGION" --table-name "$TF_LOCK_TABLE" --query 'Table.TableStatus' --output text
```

The repository's example backend already names the expected state key and lock table. Copy it locally, replace the example bucket name, and keep the resulting file untracked:

```bash
cp terraform/backend/uat.s3.tfbackend.example terraform/backend/uat.s3.tfbackend
```

The `terraform/backend/*.s3.tfbackend` pattern is in `.gitignore`. Do not upload the state file as a workflow artifact or commit backend configuration.

## 3. Create GitHub Environments first

Create the environments before the IAM roles, because the role trust policy below names the environment exactly.

1. Open the repository on GitHub: `hvb16ag4-dev/StreamingAppCapstone`.
2. Select **Settings → Environments → New environment**.
3. Create these UAT environments (spelling and capitalization matter):

   | Name | Purpose | Protection to configure now |
   |---|---|---|
   | `uat-plan` | Terraform plan against UAT state for a reviewed PR | Add `rchirutkar` under **Required reviewers**. Enable **Prevent self-review** if shown. |
   | `uat-terraform` | Apply a reviewed Terraform change to UAT | Under **Deployment branches and tags**, select **Selected branches and tags**, then add `main`. Add `rchirutkar` as a required reviewer. |
   | `uat-deploy` | Publish images and deploy the app to UAT | Select only `main` under **Deployment branches and tags**. Add `rchirutkar` as a required reviewer while UAT is first being tested. |

4. On each environment page, use **Environment variables → Add variable** for non-secret configuration only. You can add these after creating the IAM roles:

   | Variable | `uat-plan` | `uat-terraform` | `uat-deploy` |
   |---|---:|---:|---:|
   | `AWS_REGION` | `ap-south-1` | `ap-south-1` | `ap-south-1` |
   | `AWS_ACCOUNT_ID` | UAT account ID | UAT account ID | UAT account ID |
   | `AWS_TERRAFORM_ROLE_ARN` | Plan role ARN | Apply role ARN | — |
   | `AWS_DEPLOY_ROLE_ARN` | — | — | Deploy role ARN |
   | `TF_STATE_BUCKET` | State bucket name | State bucket name | — |
   | `TF_LOCK_TABLE` | `streamingapp-terraform-locks` | `streamingapp-terraform-locks` | — |
   | `EKS_CLUSTER_NAME` | — | — | `streamingapp-uat-eks` |
   | `ECR_REPOSITORY_PREFIX` | — | — | `streamingapp-uat` |

   Click **Add variable** for each name/value pair. These are identifiers, not secrets. Do not add AWS access keys. Do not add a role ARN until that role has been created.

5. Do not create the `production` environment yet. The production AWS account is not provisioned. When ready, create that environment, set its deployment branch to `main` or approved release tags, and add `rchirutkar` under **Required reviewers**.

The `uat-plan` environment approval is intentional: plans that access remote state must not automatically expose state to arbitrary pull-request code. Approve only changes from trusted contributors after inspecting the PR. The workflow must use `pull_request`, not `pull_request_target`, and must not upload state or secret-bearing plan files as artifacts.

## 4. Create the GitHub OIDC provider, then UAT IAM roles

You confirmed that the GitHub identity provider has **not** been created yet. Create it once in the UAT AWS account before creating any GitHub Actions roles.

### 4a. Create the GitHub identity provider

1. Sign in to the AWS Console and switch to the UAT account.
2. Open **IAM → Identity providers → Add provider**.
3. Choose **OpenID Connect**.
4. Enter:
   - **Provider URL:** `https://token.actions.githubusercontent.com`
   - **Audience:** `sts.amazonaws.com`
5. Choose **Add provider**.
6. Confirm `token.actions.githubusercontent.com` appears in the IAM identity provider list. If AWS reports that it already exists, open the existing provider and confirm its URL and audience match; do not create a duplicate.

The provider ARN is an IAM identifier in this form:

```text
arn:aws:iam::UAT_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

Replace `UAT_ACCOUNT_ID` with the account in which you created the provider. This provider ARN is used in each role's trust policy; it is **not** the role ARN that goes into GitHub.

### 4b. Create the three UAT IAM roles

Create one role for each distinct job capability. In the AWS Console, while still in the UAT account, for each role:

1. Open **IAM → Roles → Create role**.
2. For **Trusted entity type**, choose **Web identity**.
3. For **Identity provider**, select `token.actions.githubusercontent.com`.
4. For **Audience**, select `sts.amazonaws.com`.
5. Continue to **Add permissions**. Do **not** attach `AdministratorAccess` or an existing broad full-access policy. The role's permissions are the next step below.
6. Enter the role name, create it, then open the role's **Trust relationships → Edit trust policy**.
7. Replace/verify the trust policy has the exact provider, audience, and environment subject for that role. The `sub` string must exactly match the GitHub Environment name created in step 3.

Use these role names and subjects:

| Role name | GitHub environment subject | Purpose |
|---|---|---|
| `StreamingAppGitHubUATPlanRole` | `repo:hvb16ag4-dev/StreamingAppCapstone:environment:uat-plan` | Read-only Terraform plan plus state lock/read |
| `StreamingAppGitHubUATApplyRole` | `repo:hvb16ag4-dev/StreamingAppCapstone:environment:uat-terraform` | Apply reviewed UAT Terraform changes |
| `StreamingAppGitHubUATDeployRole` | `repo:hvb16ag4-dev/StreamingAppCapstone:environment:uat-deploy` | Push UAT images and deploy to EKS |

For each trust policy, replace `UAT_ACCOUNT_ID` with the 12-digit UAT account ID in the AWS Console. Example for the plan role:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::UAT_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:hvb16ag4-dev/StreamingAppCapstone:environment:uat-plan"
      }
    }
  }]
}
```

For the apply and deploy roles, copy the example and change only the final `sub` value to the exact value in the table. Do not use `*` in the `sub` condition. The workflows must set the matching GitHub `environment:` and request `permissions: id-token: write` or AWS will reject the OIDC exchange.

### Where to find each role ARN

After a role has been created:

1. In AWS Console, open **IAM → Roles**.
2. Search for the role name, such as `StreamingAppGitHubUATPlanRole`, and open it.
3. On the role's **Summary** page, copy the value labeled **ARN**. It will look like:

   ```text
   arn:aws:iam::UAT_ACCOUNT_ID:role/StreamingAppGitHubUATPlanRole
   ```

4. Save the ARN in a secure place while configuring GitHub. Repeat for the Apply and Deploy roles. The account ID in this ARN is not a credential; the ARN is an identifier.
5. In GitHub, add the copied ARN as an **Environment variable** in the matching environment:
   - Plan role ARN → `uat-plan` → `AWS_TERRAFORM_ROLE_ARN`
   - Apply role ARN → `uat-terraform` → `AWS_TERRAFORM_ROLE_ARN`
   - Deploy role ARN → `uat-deploy` → `AWS_DEPLOY_ROLE_ARN`

Do not paste the OIDC provider ARN into these variables; GitHub needs the **IAM role ARN**. The IAM roles can be created before their final permission policies, but a role with no permissions cannot plan, apply, push images, or deploy. Do not attach broad access just to make a test succeed. Finalize and validate each least-privilege permissions policy before enabling the corresponding workflow.

### IAM permissions: do not attach broad access

Trust policy answers **who can assume the role**; a permissions policy separately answers **what the role can do**. Attach the following narrow policies in **IAM → Policies → Create policy → JSON**. Replace all uppercase placeholders, review the JSON in IAM's policy editor, create the policy, then attach it only to the named role.

#### Terraform state backend policy (Plan and Apply roles only)

Attach the same policy to `StreamingAppGitHubUATPlanRole` and `StreamingAppGitHubUATApplyRole`. It permits reading/writing only the UAT state object and accessing only the configured lock table. Replace `UAT_ACCOUNT_ID` and `UAT_STATE_BUCKET` with your actual values; these must match `terraform/backend/uat.s3.tfbackend`.

Policy name: `StreamingAppUATTerraformStateAccess`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StateBucketLocation",
      "Effect": "Allow",
      "Action": "s3:GetBucketLocation",
      "Resource": "arn:aws:s3:::UAT_STATE_BUCKET"
    },
    {
      "Sid": "ListOnlyUATStatePrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::UAT_STATE_BUCKET",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "streamingapp/uat/terraform.tfstate",
            "streamingapp/uat/terraform.tfstate/*"
          ]
        }
      }
    },
    {
      "Sid": "ReadAndWriteOnlyUATState",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::UAT_STATE_BUCKET/streamingapp/uat/terraform.tfstate"
    },
    {
      "Sid": "UseOnlyUATStateLockTable",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:ap-south-1:UAT_ACCOUNT_ID:table/streamingapp-terraform-locks"
    }
  ]
}
```

Do not grant `s3:DeleteObject` on Terraform state. Do not attach this policy to the app deploy role. The backend policy alone is not enough to run Terraform plan/apply; it only grants backend access.

#### ECR push and EKS describe policy (Deploy role only)

Attach this only to `StreamingAppGitHubUATDeployRole`. Replace `UAT_ACCOUNT_ID`; retain the repository names and cluster name from the Terraform configuration.

Policy name: `StreamingAppUATImagePushAndEKSDescribe`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GetECRLoginToken",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "PushOnlyStreamingAppUATImages",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": [
        "arn:aws:ecr:ap-south-1:UAT_ACCOUNT_ID:repository/streamingapp-uat-auth",
        "arn:aws:ecr:ap-south-1:UAT_ACCOUNT_ID:repository/streamingapp-uat-streaming",
        "arn:aws:ecr:ap-south-1:UAT_ACCOUNT_ID:repository/streamingapp-uat-admin",
        "arn:aws:ecr:ap-south-1:UAT_ACCOUNT_ID:repository/streamingapp-uat-chat",
        "arn:aws:ecr:ap-south-1:UAT_ACCOUNT_ID:repository/streamingapp-uat-frontend"
      ]
    },
    {
      "Sid": "DescribeOnlyUATEKSCluster",
      "Effect": "Allow",
      "Action": "eks:DescribeCluster",
      "Resource": "arn:aws:eks:ap-south-1:UAT_ACCOUNT_ID:cluster/streamingapp-uat-eks"
    }
  ]
}
```

This IAM policy alone does not grant Kubernetes API permissions. After the cluster exists, create an EKS access entry for the deploy role and associate `AmazonEKSEditPolicy` scoped to namespace `streamingapp-uat`, as described in step 6. Do not use `AmazonEKSClusterAdminPolicy`.

#### Terraform infrastructure permissions (keep manual for now)

Do **not** attach `ReadOnlyAccess`, `PowerUserAccess`, or `AdministratorAccess`. The Terraform root manages VPC/subnets/routes/security groups, EKS cluster and node group, IAM roles/policies/attachments/OIDC, ECR, and S3. A Terraform plan refreshes those resources and writes refreshed state; apply can create, modify, or destroy them. Therefore, a genuine plan role also needs AWS read/describe permissions, while an apply role needs the exact resource-management API actions.

Safe next steps:

1. Attach `StreamingAppUATTerraformStateAccess` to the Plan and Apply roles only.
2. Leave their infrastructure permissions unattached and keep all Terraform operations manual under the approved IAM Identity Center profile. Do not enable an AWS-backed plan/apply workflow yet.
3. Before granting infrastructure permissions, enumerate the required AWS API actions for every `aws_*` resource in `terraform/main.tf` and the provider data sources. Scope resources by account, region, exact names/ARNs, and request/resource tags wherever AWS supports it.
4. In particular, constrain `iam:PassRole` to the two exact EKS service/node role ARNs. Never allow unrestricted role passing, IAM user/access-key creation, account administration, or organization-level actions.
5. Test a proposed policy with the IAM policy simulator and a UAT plan; inspect CloudTrail for specific denied actions. Add only the action/resource actually required. Review the final policy before attaching it and before enabling CI.

IAM Access Analyzer policy generation from CloudTrail can help identify actions after a controlled run, but its output is only a starting point; review and narrow it. Do not derive a CI role policy from unrelated administrator activity, and do not temporarily give a GitHub role broad access to “learn” its permissions. If a safe resource-specific Terraform policy is not ready, keep apply manual.

To attach one of the JSON policies: open **IAM → Policies → Create policy → JSON**, paste the matching JSON, replace placeholders, choose **Next**, name it as shown, and create it. Then open **IAM → Roles → target role → Add permissions → Attach policies**, select only the matching policy, and choose **Add permissions**. Verify the policy appears on the role's Permissions tab. The state policy belongs on the two Terraform roles; the ECR/EKS policy belongs only on the deploy role.

## 5. Add role ARNs and protect `main`

After creating each role, copy its ARN from **IAM → Roles → role name → Summary**. In the matching GitHub Environment from step 3, open **Environment variables → Add variable** and set:

- `uat-plan`: `AWS_TERRAFORM_ROLE_ARN` = plan role ARN.
- `uat-terraform`: `AWS_TERRAFORM_ROLE_ARN` = apply role ARN.
- `uat-deploy`: `AWS_DEPLOY_ROLE_ARN` = deploy role ARN.

Add the remaining non-secret values from the table in step 3. Do not put these in repository Secrets, and do not paste role ARNs into tracked workflow files.

Protect the default branch:

1. Open **Repository → Settings → Rules → Rulesets → New ruleset → New branch ruleset** (or **Branches → Add branch protection rule**, depending on the GitHub UI).
2. Name it `protect-main`, target branch `main`.
3. Require a pull request before merging. Require the pull-request validation status check once the CI workflow exists.
4. Block force pushes and branch deletion.
5. Save the ruleset. Confirm maintainers merge changes through PRs rather than pushing directly to `main`.

Do not require a status check by a name that does not exist yet; first add the workflow, run it once, then select its actual check name in the ruleset.

## 6. Create a dedicated self-hosted runner in AWS

A self-hosted runner can be created in AWS, but EC2, public IPv4, storage, and network traffic can incur charges. You can stop the runner EC2 instance when you are not using it. An Elastic IP is optional: without one, the instance's public IPv4 can change after a stop/start, and you must update the EKS API allowlist before it can deploy again. Keep AWS deployment disabled until the runner is configured and tested.

The two allowlists are separate and must not be confused:

- The EC2 security-group **inbound rules** control traffic sent to the runner instance. For this runner, keep them empty unless an approved, explicitly defined administration path requires an inbound port. `cluster_public_access_cidrs` does not modify this security group.
- `cluster_public_access_cidrs` is an EKS control-plane setting in the Terraform variable `cluster_public_access_cidrs`. It controls which source public IP CIDRs may reach the EKS Kubernetes API on port 443.
- The runner's EC2 instance role and IAM permissions are separate from the EC2 security group and the EKS API allowlist.

When choosing a deployment runner:

1. Prefer a dedicated runner for trusted deployment jobs only. Never run fork/untrusted PR code on a runner that has access to AWS or EKS.
2. A self-hosted EC2 runner needs a secure network path to the cluster. The current Terraform configuration exposes the EKS API through a CIDR allowlist and provisions public subnets. A first deployment-only runner may use an existing public subnet with no inbound security-group rules. Use either an optional Elastic IP for stable access or an auto-assigned public IP that you update in the allowlist after each runner start.
3. Give the runner host a minimal instance profile only for host management (for example, Systems Manager). GitHub Actions should assume the separate OIDC job role; do not put long-lived AWS keys on the runner.
4. Install the official GitHub Actions runner as a dedicated OS user/service, apply OS updates, and restrict it to this repository. Prefer ephemeral runners. Do not expose inbound runner ports or SSH to the internet; use an approved management path.
5. Use a runner label such as `streamingapp-uat-deploy` and configure only the trusted UAT deploy job to target that label. Keep ordinary PR checks on GitHub-hosted runners.
6. Restrict EKS public API CIDRs to the runner's current egress `/32`, or use private endpoint access. Never use `0.0.0.0/0`.

### Practical EC2 setup

Choose one EKS API allowlist option. The Terraform example currently uses a placeholder CIDR; never set it to `0.0.0.0/0`.

**Option A — no Elastic IP (less setup):**

1. Launch the runner with an auto-assigned public IPv4 address.
2. Each time the instance starts, find its current public IPv4 in **EC2 → Instances**.
3. Set `cluster_public_access_cidrs` in your ignored `terraform/environments/uat.tfvars` to `["CURRENT_RUNNER_IP/32"]` plus any separately approved operator CIDRs.
4. Run and review a Terraform plan, then apply the CIDR change before the runner attempts to contact EKS. If the IP changes, repeat these steps.

**Option B — Elastic IP (stable address, extra public IPv4 cost):**

1. Allocate an Elastic IP in `ap-south-1` and associate it with the runner.
2. Put `["RUNNER_ELASTIC_IP/32"]` in `cluster_public_access_cidrs`, plus any separately approved operator CIDRs, and apply through the reviewed Terraform process.
3. Keep the address allocated while the runner is stopped if you want to avoid changing the allowlist. Check current AWS public IPv4/Elastic IP charges; an unassociated Elastic IP may incur additional charges. Release it when no longer needed, then update the EKS allowlist before using a replacement address.

If UAT EKS already exists, update its API allowlist through Terraform and review/apply the plan before testing. Do not manually widen the cluster endpoint to the whole internet.

### Launch the EC2 host and register the runner

1. In AWS Console, open **EC2 → Instances → Launch instances**. Choose a current Ubuntu Server LTS x86_64 AMI and the existing UAT VPC/public subnet with an Internet Gateway route.
2. Use `t3.large` (2 vCPU/8 GiB) if this runner builds Docker images. If GitHub-hosted jobs build and push images and the EC2 runner only deploys them, a smaller size may work. Check current AWS pricing before launching.
3. Create an instance role `StreamingAppGitHubUATInstanceRole` with only `AmazonSSMManagedInstanceCore`. Do not attach ECR/EKS/Terraform permissions to the EC2 role; the workflow obtains its separate deploy role through OIDC.
4. Create or select a security group with **no inbound rules**. Outbound HTTPS is needed for GitHub, package/image registries, and the EKS API. Default allow-all egress works but is broad; restrict it only after confirming required endpoints and DNS. Require IMDSv2 and use an encrypted gp3 root volume (40 GiB is a starting point for Docker builds). Do not put credentials in user data.
5. Launch without an SSH key if SSM is available. If you chose Option B, associate the Elastic IP; for Option A, enable auto-assigned public IPv4. Verify **Systems Manager → Fleet Manager/Session Manager** can open a session. Do not expose SSH or other inbound ports to the internet.
6. In GitHub, open **Repository → Settings → Actions → Runners → New self-hosted runner**, select Linux and the EC2 architecture, and follow the current commands GitHub displays. In SSM, create a dedicated unprivileged user (for example `actions`) and its runner directory, then download, configure, and run the runner as that user. Do not run the runner as root.
7. The GitHub registration command contains a short-lived token. Do not paste it in chat, commit it, put it in user data, or save it in shell history. Install the runner as a service using the GitHub-provided `svc.sh` commands and restrict its directory ownership.
8. Keep PR validation on GitHub-hosted runners. The self-hosted runner must execute only trusted deployment jobs from protected `main` with `environment: uat-deploy`; never run code from forks/untrusted PRs on it. Prefer ephemeral runners later; initially keep one dedicated persistent runner patched and idle except for reviewed releases.

### What `svc.sh` does

`svc.sh` registers the downloaded GitHub Actions runner as an OS service so it continues running after SSH/SSM logout or EC2 reboot. It does not create AWS IAM roles, contact EKS, or provide AWS credentials. The normally used lifecycle commands are:

```bash
cd "$RUNNER_DIR"
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
sudo ./svc.sh stop
sudo ./svc.sh uninstall
```

Run these on the EC2 runner, not on your laptop. `$RUNNER_DIR` is the directory containing `config.sh`, `run.sh`, and `svc.sh`, for example `/home/ubuntu/actions-runner`. In normal operation, only `status` and `stop` are needed. `install` creates and starts the service once. `uninstall` removes only the local runner service; deregister the runner in GitHub separately before deleting it.

Use the GitHub-generated Linux commands for the exact install/configuration commands and runner version. Do not copy the short-lived registration token into this repository or environment file. Do not start a runner from this project directory that was only downloaded on another machine. Run `./config.sh` once on the EC2 host and use `svc.sh` to manage that host's service. The runner credential files in `_work/.credentials`, `.runner`, and `.credentials_rsaparams` are sensitive and should not be committed or shared.

The workflow runner selector will be:

```yaml
runs-on: [self-hosted, linux, x64, streamingapp-uat-deploy]
```

Verify outbound HTTPS to GitHub and TCP 443 connectivity to the EKS API endpoint. There should be no inbound runner ports. The EC2 profile is for host management only, not the GitHub workflow's deploy identity.

After the UAT cluster exists, grant the deploy role Kubernetes access:

1. In AWS Console, open **EKS → Clusters → streamingapp-uat-eks → Access → Create access entry**.
2. Choose **Standard** access and enter the ARN of `StreamingAppGitHubUATDeployRole`.
3. Create the entry. Then choose **Associate access policy** for that entry.
4. Select `AmazonEKSEditPolicy` and scope it to the `streamingapp-uat` namespace. Do not grant cluster-admin unless an explicit requirement is approved.
5. Save, wait for the access entry/policy association to propagate, then test from the runner with `aws eks update-kubeconfig` and `kubectl auth can-i` for the resources the Helm release manages.

If the EKS cluster has not yet been created, defer this access-entry step until after a reviewed Terraform apply. Runner infrastructure and traffic may incur AWS charges; no runner is created by this guide.

### Verify SSM before attempting runner registration

After attaching `StreamingAppGitHubUATInstanceRole`, the EC2 instance profile association must reach `associated`, and the EC2 instance must be able to reach AWS Systems Manager endpoints through its outbound network. Then verify in AWS Console:

1. Open **EC2 → Instances**, select the runner, and confirm **IAM instance profile** is `StreamingAppGitHubUATInstanceRole`.
2. Wait several minutes, or if the profile was attached after launch and SSM is still not visible, use **Instance state → Reboot instance**. A reboot can also restart a preinstalled SSM agent. Rebooting does not change the instance profile and does not open inbound ports.
3. Open **Systems Manager → Fleet Manager** or **Session Manager** and confirm the instance is listed and has the correct SSM ping status.
4. If it is not listed after a reboot, check whether the snap is installed. The messages `no matching snaps installed` and `snap "amazon-ssm-agent" not found` mean Snap is available but the SSM Agent snap is absent. In an Ubuntu shell on the EC2 instance, install and start it:

   ```bash
   sudo snap install amazon-ssm-agent --classic
   sudo snap start amazon-ssm-agent
   sudo snap services amazon-ssm-agent
   ```

   The last command should show the agent service as `active`. Then wait a few minutes and refresh **Systems Manager → Fleet Manager/Session Manager**. AWS recommends the Snap package for supported Ubuntu Server releases. If `snap install` itself fails because the Snap daemon is unavailable, check the AMI's `/etc/os-release` and follow the AWS SSM Agent instructions for that exact Linux distribution; do not install a second agent package alongside an existing agent.

5. If the agent is active locally but the instance still does not appear in Systems Manager, verify its instance profile is associated, the role has `AmazonSSMManagedInstanceCore`, and outbound HTTPS/DNS can reach the regional Systems Manager endpoints. An EC2 instance profile alone does not install or start the SSM Agent.
6. Use **Session Manager → Start session** to open a shell. There is no need to open port 22.

Only after SSM is available should you configure the GitHub runner. The GitHub runner is different from the EC2 instance role: the EC2 profile is for AWS/SSM host management, while the GitHub workflow deploy role is assumed separately with OIDC.

If GitHub shows the runner as **Offline** but Systems Manager shows the EC2 instance as **Online**, open **AWS Console → Systems Manager → Fleet Manager/Session Manager → Start session** for the runner. In that EC2 shell, locate the configured runner directory and check/start its service. The runner may be under the home directory of the account used to run GitHub's download commands; do not assume it is `/home/actions/actions-runner`:

```bash
sudo find /home /opt /tmp -maxdepth 5 -type f -name svc.sh -print 2>/dev/null
```

Use the directory printed by `find` (the parent directory containing `svc.sh`) as the working directory. `svc.sh` must be run from the runner root; calling it by absolute path while still in `/home` can produce `Failed: Must run from runner root or install is corrupt`. From the SSM administrative account, use:

```bash
sudo bash -c 'cd /home/actions/actions-runner && ./svc.sh status'
```

If the service is installed but stopped, start it and verify:

```bash
sudo bash -c 'cd /home/actions/actions-runner && ./svc.sh start'
sudo bash -c 'cd /home/actions/actions-runner && ./svc.sh status'
```

If the runner was configured with `./config.sh` but the service has not yet been installed, use the SSM session's administrative account (for example, `ssm-user` or `ubuntu`) to install the service for the account that owns the runner directory. If you cannot access the directory directly, run `sudo stat -c '%U' /path/to/actions-runner/svc.sh` to check its owner. Do not run these `sudo` commands from the runner account if it is not allowed to use sudo:

```bash
sudo bash -c 'cd /path/to/actions-runner && ./svc.sh install RUNNER_USER'
sudo bash -c 'cd /path/to/actions-runner && ./svc.sh start'
sudo bash -c 'cd /path/to/actions-runner && ./svc.sh status'
```

Replace `/path/to/actions-runner` with the actual directory and `RUNNER_USER` with the owner reported by `stat`. If currently in the runner account's shell, type `exit` to return to the SSM admin shell first. Do not run `config.sh` again if the runner is already configured. Then refresh **Repository → Settings → Actions → Runners** and confirm the runner changes to **Idle**. If the service fails, inspect the runner `_diag` logs from the EC2 shell; do not share `.credentials` or registration tokens.

### Register the runner on EC2

1. Open GitHub **Repository → Settings → Actions → Runners → New self-hosted runner**.
2. In an SSM Session Manager shell, create a dedicated OS user and runner directory. The following example uses Ubuntu's `actions` account:

   ```bash
   sudo adduser --disabled-password --gecos "" actions
   sudo install -d -o actions -g actions /home/actions/actions-runner
   sudo -iu actions
   cd /home/actions/actions-runner
   ```

   If the `actions` user already exists, do not create it again; confirm the account and directory ownership before continuing. Install any prerequisites listed by GitHub for the EC2 operating system.
3. Generate the Linux installation commands for the repository and architecture. As the `actions` user, run GitHub's version-specific download and extraction commands in `/home/actions/actions-runner`, then run its configuration command to register the runner at repository scope with the `streamingapp-uat-deploy` label. Do not run `config.sh` as root. The registration token is short-lived; do not paste it in chat, commit it, or put it in user data.
4. For a one-time connectivity check, running `./run.sh` should print `Listening for Jobs`. This runs in the foreground and stops when the shell/session ends; it is not the persistent service.
5. To run it persistently, stop the foreground process with **Ctrl+C** first, then return to the SSM administrative shell by typing `exit`. From that shell, go to the actual runner directory and install/start the service for its owning account. For the example account and path above:

   ```bash
   sudo bash -c 'cd /home/actions/actions-runner && ./svc.sh install actions'
   sudo bash -c 'cd /home/actions/actions-runner && ./svc.sh start'
   sudo bash -c 'cd /home/actions/actions-runner && ./svc.sh status'
   ```

   If you used another account or directory, substitute those values. The service commands must execute from the runner root; the `cd` inside `sudo bash -c` handles this even when the SSM account cannot traverse the runner user's home directory. The `svc.sh install <username>` command needs administrative privileges to register the OS service, while the runner itself runs as the unprivileged user. Do not run `./run.sh` and the service simultaneously for the same runner.
6. GitHub should show the runner as **Idle** or **Online** when it has connected. If it remains offline, inspect the runner's `_diag` logs and ensure the EC2 host has outbound HTTPS connectivity to GitHub.
7. Do not use an organization-wide runner unless it is intentionally approved, and do not copy an existing local laptop `actions-runner` credential directory to EC2. Register once on EC2 and generate a separate runner credential set.

### Stop and restart the runner to control cost

When you finish a deployment session:

1. In GitHub, verify no workflow job is running or queued for this runner.
2. In **EC2 → Instances**, select the runner and choose **Instance state → Stop instance**. Do not terminate it unless you are intentionally deleting it.
3. A stopped instance does not incur EC2 compute charges, but its EBS volumes continue to incur storage charges. Public IPv4/Elastic IP charges may also continue; review current pricing. An auto-assigned public IPv4 is normally released on stop, so the address will change on the next start. An associated Elastic IP remains stable but may be billed as a public IPv4.
4. To use it again, start the instance, wait for the GitHub runner to report **Idle/Online**, and check its current public IP. If it changed, update `cluster_public_access_cidrs` to the new `/32` and apply the reviewed Terraform update before running a deployment.
5. If you do not plan to use the runner again, deregister it from **Repository → Settings → Actions → Runners**, terminate the EC2 instance, remove its dedicated security group/instance profile only if no longer used, and release its Elastic IP if allocated. Do not delete resources shared with EKS.

The runner is independent of EKS. Stopping the runner does not stop or change the cluster.

## 7. Reduce UAT costs when the project is idle

Amazon EKS does **not** provide a stop button for the cluster control plane. Stopping the EC2 runner does not stop EKS. Setting the managed node group's desired/minimum capacity to zero can stop worker-node compute, but the EKS control plane remains billable, and other resources (such as ALBs, EBS volumes, public IPv4 addresses, S3, and Terraform state storage) may continue to incur charges.

For short breaks, scaling the node group to zero may be appropriate, but the current Terraform examples set a minimum of one node. Update `min_capacity` and `desired_capacity` in the ignored UAT tfvars only after confirming the EKS managed node group supports the requested capacity, review and apply the Terraform plan, and remove unused Ingress/load balancers and persistent resources where safe. Do not leave an ALB or NAT/public IP running without a reason.

For the lowest ongoing project cost after screenshots, the complete UAT application environment can be **destroyed and recreated later**. This is not a pause; it removes EKS and its network/compute resources. The remote Terraform state bucket and lock table are bootstrap resources outside this Terraform root and should remain. Recreating the environment requires a new reviewed `terraform apply`, cluster add-ons/access setup, image deployment, and fresh endpoint validation.

Before full destroy:

1. Save required screenshots and export/back up any MongoDB data, uploaded media, or configuration you need. Destroying the cluster can delete the MongoDB persistent volume and its data.
2. Authenticate to the UAT account, update kubeconfig, uninstall the Helm release, and wait until the AWS Load Balancer Controller deletes the ALB:

   ```bash
   aws sso login --profile YOUR_UAT_PROFILE
   aws sts get-caller-identity --profile YOUR_UAT_PROFILE
   aws eks update-kubeconfig --profile YOUR_UAT_PROFILE --region ap-south-1 \
     --name streamingapp-uat-eks
   helm uninstall streamingapp-uat --namespace streamingapp-uat
   kubectl get ingress,service -n streamingapp-uat
   ```

   If your release or namespace names differ, use the actual values. Confirm the Ingress and its ALB are removed before destroying the VPC.
3. Check Terraform state and the destroy plan carefully. The media S3 bucket uses `force_destroy = false`; if it contains objects, including versions, Terraform will not empty it automatically and destroy may stop with an error. Decide explicitly whether to preserve media or remove all object versions before retrying. Never delete data just to make destroy succeed.
4. Run the destroy plan from the Terraform directory using the UAT profile, backend, and tfvars. Review every resource before applying:

   ```bash
   cd terraform
   export AWS_PROFILE=YOUR_UAT_PROFILE
   aws sts get-caller-identity --profile "$AWS_PROFILE"
   terraform init -reconfigure -backend-config=backend/uat.s3.tfbackend
   terraform plan -destroy -var-file=environments/uat.tfvars
   ```

   Only if the account and plan are correct, run `terraform destroy -var-file=environments/uat.tfvars` and review/confirm its plan. Do not destroy the remote state bucket or lock table; they are outside this Terraform root. If Terraform stops because the media bucket is nonempty, stop and decide whether to retain the bucket/environment or deliberately back up and remove all object versions. Do not force-delete it.
5. Verify in AWS that EKS, node group, load balancers, EBS volumes, and any unneeded public IPv4 resources are gone. Confirm the remote state bucket/table and any intentionally retained media bucket remain.

To recreate, run a fresh reviewed UAT `terraform plan -var-file=environments/uat.tfvars` and `terraform apply -var-file=environments/uat.tfvars` using the existing remote backend. Then recreate any EKS access entries, install/verify the AWS Load Balancer Controller and EBS CSI/default StorageClass, and deploy the app. Do not assume add-ons or access entries are recreated unless they are defined by Terraform or explicitly re-applied.

## 8. Enable automation only after the workflow exists

At present, there are no GitHub Actions workflows in the repository. Creating IAM roles and environments does not itself run CI/CD. The workflow implementation must:

- use immutable image tags derived from the source commit;
- use OIDC and the exact Environment/role pairing above;
- set least-privilege `permissions` per job, including `id-token: write` only where AWS credentials are needed;
- never run AWS-authenticated jobs on untrusted PR code;
- keep UAT Terraform plan/apply separate from image build/deploy;
- avoid Terraform state and credentials as workflow artifacts;
- be noninteractive. The current `scripts/k8s-deploy.sh aws` uses a local AWS profile and asks for interactive confirmation, so it cannot be called unchanged from Actions.

Before any automated apply or release, confirm the UAT account, backend key, lock table, CIDR restrictions, reviewed Terraform plan, EKS access, AWS Load Balancer Controller, EBS CSI/default StorageClass, and deployment health checks. Keep applies manual until the least-privilege policies and workflow have both been validated.

Production is not ready: its AWS account does not exist yet. Later, create a separate production state bucket/table, separate OIDC roles and trust subjects, production EKS networking and access, and a GitHub `production` Environment with `rchirutkar` as a required reviewer. Use the ALB URL for UAT until the domain and TLS configuration are ready.

## What to do next

You have reported that GitHub Environments and the three UAT roles exist, their ARNs are configured as environment variables, and `main` is protected. Next:

1. Verify/create `token.actions.githubusercontent.com` as the UAT IAM OIDC provider before using the roles.
2. Attach `StreamingAppUATTerraformStateAccess` to the Plan and Apply roles and `StreamingAppUATImagePushAndEKSDescribe` to the Deploy role after replacing placeholders.
3. Keep Terraform infrastructure permissions and CI deployment disabled until the least-privilege policy and workflow are reviewed.
4. The self-hosted runner is configured and Idle. Keep it stopped when not needed to reduce compute charges; its public IP can change after restart.
5. Before workflow automation, verify the OIDC provider and role policies, then use the manual UAT deployment process to validate the cluster, add-ons, app, and screenshots.

At the latest user-reported verification point, the runner is **Idle** in GitHub and its EC2 instance uses Systems Manager. It has no Elastic IP, so its auto-assigned public IP may change after a stop/start. The last confirmed status was that no EKS cluster named `streamingapp-uat-eks` existed; verify whether it has since been provisioned before trying the manual deploy.

Do not send credentials or tokens in chat. Account IDs, resource names, and role ARNs are identifiers; AWS access keys, session tokens, and Terraform state are sensitive.
