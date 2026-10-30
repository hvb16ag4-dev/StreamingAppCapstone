# Configure an existing S3 bucket for local Kubernetes testing

This guide connects the local Kubernetes app to an S3 bucket you already created. It covers the IAM Identity Center operator role, a separate bucket-scoped role for the app's temporary session, and the environment variables expected by `scripts/k8s-deploy.sh`.

The bucket ARN you supplied, `arn:aws:s3:::xxxxxx-s3-test-001`, identifies the bucket but is **not** the value for `AWS_S3_BUCKET`. Use the bucket's actual name, `xxxxxx-s3-test-001` (replace `xxxxxx` with the real characters if you masked them), without `arn:aws:s3:::`. Keep the bucket in the same AWS account as the role for this guide.

## What you'll configure

1. An IAM Identity Center permission set assigned to your operator, with permission to assume one specific role.
2. A new IAM role trusted by the permission set's generated IAM role.
3. An IAM policy attached to the new role that grants access only to the existing test bucket.
4. Local environment variables telling the deployment helper the profile, account, bucket name, region, and new role ARN.

The deployment helper assumes this role for one hour and places the temporary credentials in a Kubernetes Secret. Do not create access keys or paste credentials into `.env`, Helm values, Git, or chat.

## 1. Confirm the AWS account, region, and bucket name

Find the bucket's **name** and **AWS Region** in the S3 console. The bucket name is the final component of its ARN. For example:

| Value | Example |
|---|---|
| Bucket ARN | `arn:aws:s3:::my-streamingapp-test-001` |
| `AWS_S3_BUCKET` | `my-streamingapp-test-001` |
| `AWS_REGION` | The region shown for that bucket, e.g. `ap-south-1` |

Use the bucket's actual region below. The account ID is a 12-digit number; do not use the masked `xxxxxx` text as the account ID.

## 2. Configure or select your IAM Identity Center profile

Your `~/.aws/config` currently defines a reusable SSO session:

```ini
[sso-session capstone-sso]
sso_start_url = https://d-9f675baa0a.awsapps.com/start
sso_region = ap-south-1
sso_registration_scopes = sso:account:access
```

That session block is valid, but it does not select an AWS account or permission set. Add a profile that references it. Replace the account ID with the 12-digit account that owns the bucket, `YOUR_PERMISSION_SET_NAME` with the permission set name assigned to you in IAM Identity Center, and `YOUR_BUCKET_REGION` with the bucket's AWS region:

```ini
[profile streamingapp-local]
sso_session = capstone-sso
sso_account_id = 123456789012
sso_role_name = YOUR_PERMISSION_SET_NAME
region = YOUR_BUCKET_REGION
output = json
```

For example, if the permission set is named `StreamingAppLocal` and the bucket is in `ap-south-1`:

```ini
[profile streamingapp-local]
sso_session = capstone-sso
sso_account_id = 123456789012
sso_role_name = StreamingAppLocal
region = ap-south-1
output = json
```

`sso_region` is the region where IAM Identity Center is configured. The profile's `region` is the default AWS service region, and should match the S3 bucket's region for this test. They may be different in another setup. `sso_role_name` is the permission set name shown by the Identity Center access portal, not the generated `AWSReservedSSO_...` IAM role name.

Edit `~/.aws/config` without deleting the existing session block. You can also create a profile interactively instead:

```bash
aws configure sso --profile streamingapp-local
```

When prompted, use the existing start URL and SSO region, then select the bucket-owning account and the permission set. Do not type a bare `--profile`; it requires a profile name after it.

Sign in and verify the profile:

```bash
aws sso login --profile streamingapp-local
aws sts get-caller-identity --profile streamingapp-local
```

Confirm the returned `Account` is the bucket-owning account. Record it for `EXPECTED_AWS_ACCOUNT_ID`. If the profile already exists and works for that account, use its name instead of `streamingapp-local` in the rest of this guide.

If AWS CLI rejects `sso_session`, check `aws --version`; IAM Identity Center's `sso-session` profile format requires AWS CLI v2. Update to a current AWS CLI v2 release, then retry the login and identity check.

## 3. Find the IAM Identity Center role ARN

The trust policy needs the **IAM role ARN generated for your permission set in the AWS account**. It does not use the permission set ARN, your email, or the STS assumed-role ARN printed by `get-caller-identity`.

In the AWS console, open **IAM → Roles**, search for `AWSReservedSSO_` and locate the role whose name matches the permission set selected in step 2. Open it and copy its **Role ARN**. It commonly looks like:

```text
arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_StreamingAppLocal_abc123...
```

The IAM Identity Center region can appear in the role path, for example `.../sso.amazonaws.com/us-east-1/AWSReservedSSO_...`. Copy the ARN shown by IAM exactly. The final random suffix is part of the role name; do not omit it.

You can confirm the active caller is an IAM Identity Center session with:

```bash
aws sts get-caller-identity --profile streamingapp-local --query Arn --output text
```

That command usually prints an `arn:aws:sts::...:assumed-role/AWSReservedSSO_.../...` ARN. It is useful for confirming the permission set name, but use the corresponding **IAM role ARN from IAM → Roles** in the trust relationship.

Each permission set has its own generated IAM role in the account. If more than one permission set should be allowed to use the local bucket, find each permission set's exact IAM role ARN and allow-list those ARNs in the trust policy. For multiple roles, use a JSON array:

```json
"Principal": {
  "AWS": [
    "FIRST_PERMISSION_SET_IAM_ROLE_ARN",
    "SECOND_PERMISSION_SET_IAM_ROLE_ARN"
  ]
}
```

Grant `sts:AssumeRole` on the local S3 role to each of those permission sets as well. Do not use a wildcard principal.

## 4. Create a bucket-scoped IAM policy

In the console, open **IAM → Policies → Create policy → JSON** and create a policy like the following. Replace `BUCKET_NAME` with the exact bucket name (no ARN prefix). This permits the app to list the bucket and read, upload, or delete objects; it does not grant access to other buckets.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListTestBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::BUCKET_NAME"
    },
    {
      "Sid": "ManageTestBucketObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::BUCKET_NAME/*"
    }
  ]
}
```

Name it, for example, `StreamingAppLocalTestBucketAccess`. Do not add `s3:*` or `Resource: "*"`. If your bucket uses a customer-managed KMS key instead of S3-managed encryption, the role will also need narrowly scoped KMS permissions for that key; do not add them unless that is how the bucket is configured.

## 5. Create the local test access role

In the console, open **IAM → Roles → Create role**. Choose a custom trust policy (or create an AWS-account role and edit its trust relationship before proceeding). Use this trust policy, substituting the exact permission-set **IAM role ARN** from step 3:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "PERMISSION_SET_IAM_ROLE_ARN"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Attach the `StreamingAppLocalTestBucketAccess` policy from step 4, name the role `StreamingAppLocalS3TestRole` (or another clear name), and create it. Copy the new role's **Role ARN**; this becomes `LOCAL_S3_ROLE_ARN`.

The trust policy controls who may assume this role. The attached permission policy controls what the assumed role may access. Keep both restrictions in place.

## 6. Allow your permission set to assume the new role

The trust policy alone is not enough: your signed-in permission set also needs an identity policy allowing `sts:AssumeRole` on the exact new role ARN.

In **IAM Identity Center → Permission sets**, select the permission set you use for this test and add an inline policy limited to that role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "LOCAL_S3_ROLE_ARN"
    }
  ]
}
```

Replace `LOCAL_S3_ROLE_ARN` with the exact role ARN copied in step 5. Save the permission set and allow IAM Identity Center to provision its update to the account. If an administrator manages permission sets for your organization, ask them to make this narrowly scoped change.

## 7. Export the local deployment settings

From the repository root in the same terminal where you will run the helper, set the actual values. `EXPECTED_AWS_ACCOUNT_ID` is the 12-digit bucket-owning account ID. `AWS_S3_BUCKET` is the bucket name, **not its ARN**.

```bash
export AWS_PROFILE=streamingapp-local
export EXPECTED_AWS_ACCOUNT_ID=123456789012
export AWS_REGION=ap-south-1
export AWS_S3_BUCKET=your-actual-bucket-name
export LOCAL_S3_ROLE_ARN=arn:aws:iam::123456789012:role/StreamingAppLocalS3TestRole

aws sso login --profile "$AWS_PROFILE"
aws sts get-caller-identity --profile "$AWS_PROFILE"
```

Replace all example values. Check that the bucket region matches `AWS_REGION`, and that the caller account matches `EXPECTED_AWS_ACCOUNT_ID`.

## 8. Verify assume-role access and deploy locally

First verify the operator is allowed to assume the role. This prints only the assumed role identity, not its temporary secrets:

```bash
aws sts assume-role \
  --profile "$AWS_PROFILE" \
  --role-arn "$LOCAL_S3_ROLE_ARN" \
  --role-session-name streamingapp-local-test \
  --duration-seconds 3600 \
  --query 'AssumedRoleUser.Arn' \
  --output text
```

If successful, deploy the local app:

```bash
./scripts/k8s-deploy.sh local
```

The helper validates the account, assumes the role, checks access to the named bucket, writes temporary credentials to the `streamingapp-object-store` Kubernetes Secret without displaying them, and deploys. After the one-hour credentials expire, refresh them with:

```bash
./scripts/k8s-deploy.sh refresh-local-aws-credentials
```

## Troubleshooting `AWS_S3_BUCKET is not configured`

The helper expects a **bucket name** in an exported environment variable. An ARN by itself does not populate that variable. In the same terminal, run:

```bash
export AWS_S3_BUCKET=your-actual-bucket-name
printf 'Bucket configured: %s\n' "$AWS_S3_BUCKET"
```

Do not include `arn:aws:s3:::` or a trailing slash. Also set `AWS_PROFILE`, `EXPECTED_AWS_ACCOUNT_ID`, and `LOCAL_S3_ROLE_ARN` as shown above, then rerun the helper.

If the next error is `Unable to assume the restricted local DEV S3 role`, check both sides of the assume-role authorization:

- The role trust policy names the exact permission-set IAM role ARN from **IAM → Roles**.
- The permission set has `sts:AssumeRole` permission on the exact local role ARN.
- Your current profile is signed in to the expected account and the permission-set update has been provisioned.

If the helper reports it cannot access the bucket, confirm the role has the IAM policy from step 4, `AWS_S3_BUCKET` is the correct name, `AWS_REGION` matches the bucket's region, and the bucket does not have an explicit deny or a restrictive organization policy. The script runs `head-bucket` using the assumed credentials before creating/updating the Kubernetes Secret.

## Bucket security and cleanup

Keep S3 Block Public Access enabled. S3 does not need a public bucket policy for this setup; the assumed role accesses objects privately. Enable default encryption and versioning for test data if appropriate, and remember that stored videos incur S3 storage/request charges. Delete test objects when no longer needed, including object versions if versioning is enabled. Do not delete the bucket or its data until you have confirmed it is safe to do so.
