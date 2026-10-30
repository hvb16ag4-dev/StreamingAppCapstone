# Local Kubernetes test with AWS S3

This guide deploys the current Helm chart to a local Kubernetes cluster before using EKS. Docker Desktop Kubernetes is the simplest path on Windows/WSL. Minikube is a suitable alternative. The local cluster does not provision AWS resources; it requires the pre-provisioned, isolated DEV bucket and assumed role in the UAT account.

The local Kubernetes test builds the five app images, pulls `mongo:6`, and uses a separate private DEV media bucket in the UAT AWS account. It disables the AWS ALB Ingress and uses `kubectl port-forward` for local browser/API access. The helper assumes a restricted AWS role for one hour and places the temporary credentials in a Kubernetes Secret; it does not use static keys.

## One-command deployment helper

First configure the UAT bucket/role as described in [environment-configuration.md](./environment-configuration.md), authenticate with the UAT IAM Identity Center profile, and export `AWS_PROFILE`, `EXPECTED_AWS_ACCOUNT_ID`, `AWS_REGION`, `AWS_S3_BUCKET` (the local DEV bucket output), and `LOCAL_S3_ROLE_ARN` (the local DEV role output). Then run from the repository root:

```bash
chmod +x scripts/k8s-deploy.sh
./scripts/k8s-deploy.sh local
```

This checks Docker Desktop Kubernetes, rebuilds the four backend images and a frontend image with localhost API URLs, ensures local JWT and temporary AWS credential Secrets exist, upgrades the Helm release, restarts S3 clients with refreshed credentials, starts managed port-forwards, and checks all five HTTP endpoints. Open `http://localhost:3000` for screenshots. Secret values are never printed.

When the port-forwards stop but the release still exists, run `./scripts/k8s-deploy.sh local` again; it reconciles the release and restarts the tunnels. Other helpers:

```bash
./scripts/k8s-deploy.sh status
./scripts/k8s-deploy.sh forward-local
./scripts/k8s-deploy.sh refresh-local-aws-credentials
./scripts/k8s-deploy.sh stop-local
```

`stop-local` only stops the managed port-forwards. `forward-local` restarts the tunnels and checks endpoints without rebuilding or changing the release. `refresh-local-aws-credentials` assumes a fresh one-hour S3 role session and restarts the admin/streaming Deployments. To remove the local Helm release, run `helm uninstall streamingapp --namespace streamingapp`; removing the namespace deletes local Kubernetes objects, but does not delete the AWS S3 bucket or its objects. Remove AWS resources only through a separately reviewed Terraform plan.

For Minikube, select its context when running the helper:

```bash
KUBE_CONTEXT=minikube ./scripts/k8s-deploy.sh local
```

## 1. Enable a local Kubernetes cluster

### Option A — Docker Desktop Kubernetes (recommended)

1. Install/start Docker Desktop.
2. In Docker Desktop settings, enable Kubernetes and apply/restart.
3. If using WSL, enable Docker Desktop WSL integration for the distro containing the repository.
4. Open a new WSL terminal and verify the tools/context:

   ```bash
   docker version
   kubectl version --client
   kubectl config get-contexts
   kubectl config use-context docker-desktop
   kubectl cluster-info
   kubectl get nodes
   helm version
   ```

Use the context name displayed by `kubectl config get-contexts` if it differs from `docker-desktop`.

### Option B — Minikube

Install Docker Desktop (or another supported driver), `kubectl`, and Minikube. From the repository's WSL shell:

```bash
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=30g
kubectl config use-context minikube
kubectl get nodes
```

The local build and Helm steps below are the same. If Minikube cannot see Docker Desktop images, load them explicitly with the `minikube image load <image:tag>` commands in the image section.

## 2. Configure local environment values

Compose reads the ignored repository-root `.env` file. Helm/Kubernetes does **not** read that file; Kubernetes receives normal settings through Helm values and JWT/temporary AWS credentials through Kubernetes Secrets.

For Compose/local image builds, create `.env` in the repository root with local-only values:

```ini
MONGO_DB=streamingapp
CLIENT_URLS=http://localhost:3000
IMAGE_PREFIX=streamingappcapstone
IMAGE_TAG=latest
STREAMING_PUBLIC_URL=http://localhost:3002
REACT_APP_AUTH_API_URL=http://localhost:3001/api
REACT_APP_STREAMING_API_URL=http://localhost:3002/api
REACT_APP_STREAMING_PUBLIC_URL=http://localhost:3002
REACT_APP_ADMIN_API_URL=http://localhost:3003/api/admin
REACT_APP_CHAT_API_URL=http://localhost:3004/api/chat
REACT_APP_CHAT_SOCKET_URL=http://localhost:3004
```

`.env` is ignored by Git. Do not put AWS credentials, JWTs, or temporary credentials in it. The local helper creates the JWT Secret and refreshes the short-lived, bucket-scoped AWS credential Secret without printing its values.

## 3. Build images locally

From the repository root:

```bash
docker compose build auth streaming admin chat
docker compose pull mongo
docker image ls
```

With the default prefix/tag, the four backend images are:

- `streamingappcapstone-auth:latest`
- `streamingappcapstone-streaming:latest`
- `streamingappcapstone-admin:latest`
- `streamingappcapstone-chat:latest`

The helper passes the configured prefix/tag to Helm. To use custom local image names, export matching `IMAGE_PREFIX` and `IMAGE_TAG` values before running the helper.

Build a separate frontend image for port-forward-based browser access. CRA bakes these addresses into the static bundle at build time:

```bash
docker build -t streamingapp-frontend:k8s-local \
  --build-arg REACT_APP_AUTH_API_URL=http://localhost:3001/api \
  --build-arg REACT_APP_STREAMING_API_URL=http://localhost:3002/api \
  --build-arg REACT_APP_STREAMING_PUBLIC_URL=http://localhost:3002 \
  --build-arg REACT_APP_ADMIN_API_URL=http://localhost:3003/api/admin \
  --build-arg REACT_APP_CHAT_API_URL=http://localhost:3004/api/chat \
  --build-arg REACT_APP_CHAT_SOCKET_URL=http://localhost:3004 \
  ./frontend
```

Do not rely on React environment variables added to the running Nginx container; the frontend is already compiled. If using Minikube and the cluster cannot access the Docker Desktop image cache, load all five app images:

```bash
minikube image load streamingappcapstone-auth:latest
minikube image load streamingappcapstone-streaming:latest
minikube image load streamingappcapstone-admin:latest
minikube image load streamingappcapstone-chat:latest
minikube image load streamingapp-frontend:k8s-local
```

The MongoDB image does not need to be built: Kubernetes pulls `mongo:6` from Docker Hub. The PVC stores local cluster Mongo data; check that a default StorageClass exists with `kubectl get storageclass`.

## 4. Render, install, and verify the Helm release

The example local values set localhost CORS origins, an AWS S3 endpoint with path-style addressing disabled, and disable the AWS ALB Ingress. The helper supplies the account-specific bucket and temporary credential Secret name. Keep all credentials out of this values file.

```bash
helm lint ./helm/streamingapp
helm template streamingapp ./helm/streamingapp \
  --namespace streamingapp \
  --values ./helm/streamingapp/values-local.yaml.example

./scripts/k8s-deploy.sh local
```

The helper creates a random JWT Secret and assumes a bucket-scoped role to create a temporary AWS credential Secret. Do not replace these with manually generated long-lived access keys. The chart composes each backend Mongo URI using the release's Mongo Service name; use release `streamingapp` so it resolves to `streamingapp-mongo`.

Check workload and storage status:

```bash
kubectl -n streamingapp get deployments,pods,services,pvc
kubectl -n streamingapp rollout status deployment/streamingapp-auth
kubectl -n streamingapp rollout status deployment/streamingapp-streaming
kubectl -n streamingapp rollout status deployment/streamingapp-admin
kubectl -n streamingapp rollout status deployment/streamingapp-chat
kubectl -n streamingapp rollout status deployment/streamingapp-frontend
kubectl -n streamingapp rollout status deployment/streamingapp-mongo
```

The local setup does not install an Ingress controller. In five terminals, forward the frontend and API services:

```bash
kubectl -n streamingapp port-forward service/streamingapp-frontend 3000:80
kubectl -n streamingapp port-forward service/streamingapp-auth 3001:3001
kubectl -n streamingapp port-forward service/streamingapp-streaming 3002:3002
kubectl -n streamingapp port-forward service/streamingapp-admin 3003:3003
kubectl -n streamingapp port-forward service/streamingapp-chat 3004:3004
```

Then check the endpoints and open `http://localhost:3000`:

```bash
curl -fsS http://localhost:3001/health
curl -fsS http://localhost:3002/api/health
curl -fsS http://localhost:3003/api/health
curl -fsS http://localhost:3004/api/health
curl -I http://localhost:3000
```

Register a user, then for a local admin test promote that user's role in MongoDB:

```bash
kubectl -n streamingapp exec -it deployment/streamingapp-mongo -- mongosh streamingapp
```

In `mongosh`, replace the email with the registered account:

```javascript
db.users.updateOne({ email: "you@example.com" }, { $set: { role: "admin" } })
```

Sign out and back in, open `/admin`, and upload a small video plus thumbnail. The upload is stored in the isolated local-DEV AWS S3 bucket; metadata goes to MongoDB. Browse and play the video to test byte-range streaming. Use `kubectl -n streamingapp get deployments,pods,services,pvc` to check the app. This tests AWS S3 using the restricted local role, not the EKS IRSA path.

If a pod does not start, inspect its events and logs:

```bash
kubectl -n streamingapp describe pod <pod-name>
kubectl -n streamingapp logs deployment/<deployment-name> --all-containers=true
```

`ImagePullBackOff` usually means the local image name/tag is wrong or the cluster cannot see the local image. `Pending` Mongo PVC commonly means there is no default StorageClass. Backend startup errors should be checked for Mongo readiness and the generated JWT Secret.

### Verified local Kubernetes run

On 2026-10-29, Docker Desktop Kubernetes was verified from WSL using the `docker-desktop` context. The single cluster node was `Ready`, and the default `standard` StorageClass provisioned the Mongo PVC. The chart installed successfully from `values-local.yaml.example`; all six Deployments (MongoDB, four backend services, frontend) reached `1/1` Ready, and the PVC became `Bound`.

The five `kubectl port-forward` commands above were started and all HTTP checks passed:

| Endpoint | Result |
|---|---|
| `http://localhost:3000` (frontend) | HTTP 200 |
| `http://localhost:3001/health` (auth) | HTTP 200 |
| `http://localhost:3002/api/health` (streaming) | HTTP 200 |
| `http://localhost:3003/api/health` (admin) | HTTP 200 |
| `http://localhost:3004/api/health` (chat) | HTTP 200 |

During first startup, backend containers restarted while MongoDB was still initializing; all backend logs subsequently confirmed a MongoDB connection and all Deployments became Ready. For a production-quality rollout, add probes and improve startup/readiness handling so health is not reported before database dependencies are available.

On 2026-10-29, after the port-forward tunnels had stopped, `scripts/k8s-deploy.sh local` successfully rebuilt/reconciled the local release, restarted all five tunnels, and rechecked the same five HTTP 200 endpoints. `scripts/k8s-deploy.sh status` also passed afterward.

## 5. Reset the local test

Stop the port-forward commands with Ctrl+C. Remove the release:

```bash
helm uninstall streamingapp --namespace streamingapp
```

To delete the namespace and its Mongo PVC/data too:

```bash
kubectl delete namespace streamingapp
```

Deleting the namespace does not delete the local DEV S3 bucket. Keep or remove its objects according to the agreed retention policy; versioned objects may need to be removed before Terraform can delete the bucket. Docker Compose containers are separate; stop those with `docker compose down` if they were also started.

## 6. Move from local Kubernetes to AWS

Once local Kubernetes passes, use the same chart but substitute ECR image URIs, configure approved IAM Identity Center access, give Terraform the approved trusted API CIDR, and create the runtime Secret in EKS. Install AWS Load Balancer Controller and the required storage provisioner/CSI driver before depending on ALB ingress and Mongo PVC provisioning. Review the Terraform plan and costs before applying. Do not copy local `.env`, local Kubernetes Secrets, or Docker credentials to AWS.

After an approved operator has separately provisioned the cluster, ECR repositories, ALB controller, and default EBS CSI StorageClass, the helper can build/tag/push app images and deploy them:

```bash
aws sso login --profile streamingapp
export AWS_PROFILE=streamingapp
export EXPECTED_AWS_ACCOUNT_ID=YOUR_APPROVED_ACCOUNT_ID
export TRUSTED_EKS_API_CIDR=YOUR_TRUSTED_PUBLIC_IP/32
export DEPLOY_ENV=uat
export AWS_REGION=ap-south-1
export EKS_CLUSTER_NAME=streamingapp-uat-eks
./scripts/k8s-deploy.sh aws
```

For full account-specific Terraform values, state-backend warning, S3/IRSA outputs, and UAT/PROD commands, see [environment-configuration.md](./environment-configuration.md). The AWS helper checks the short-lived assumed-role identity/account, trusted API CIDR, environment-specific ECR repositories, ALB Controller rollout, and default StorageClass. It requires the environment's `AWS_S3_BUCKET` and `APP_MEDIA_ROLE_ARN`, then prompts for the literal confirmation `deploy` before pushing images and deploying. **It does not run `terraform apply`**; AWS resources and data may incur cost. The current ALB values use HTTP; configure HTTPS, DNS, and a certificate before production.

Do not use the generated in-cluster Secret workflow as a production secret-management design. For longer-lived environments, configure external secret management/rotation and remote Terraform state with locking first.

## Comparison: `feature_orchestration_scaling`

The branch was inspected without checking it out or changing it. It has a Jenkins ECR build/push and one Helm deployment to the `streamingapp` namespace, plus both a Helm chart and a duplicate standalone `k8s/` manifest tree. The duplicate sources can drift.

The actual branch manifests do **not** implement Milestone 3 autoscaling or monitoring: there is no HPA, Prometheus/Grafana, or metrics configuration. Helm has a replica count (2), and the standalone YAML sets two replicas, but fixed replicas are not autoscaling. There is no Ingress resource in the chart/manifests, despite the docs referring to an AWS LoadBalancer; no service/Ingress route is defined to provide that path. The Jenkinsfile deploys to one namespace, with no separate dev/UAT/prod promotion, rollback stage, HPA configuration, or rollout verification.

The branch's Jenkinsfile references static AWS credentials in Jenkins credentials and injects AWS access keys into a Kubernetes Secret. Do not carry that pattern forward; use short-lived role-based credentials and IRSA/workload identity. The branch's README says CloudWatch Observability was installed, but the inspected repository files do not provide a repeatable installation/configuration for it. Its future-enhancements list explicitly names HPA and Prometheus/Grafana, consistent with those not being implemented.

Recommendation: keep the current `feature_terraform` chart/Terraform as the base after local Kubernetes validation. Reuse useful CI ideas from `feature_orchestration_scaling` only after correcting the credential approach; do not merge its duplicate manifests or treat the documented autoscaling/monitoring as implemented.

## Milestone 3 readiness

Milestone 3 is not implemented by either branch yet. Plan it after the local Kubernetes and AWS manual deployments are reproducible:

1. Make one Helm chart the deployment source of truth; remove or clearly deprecate duplicate standalone manifests.
2. Add readiness/liveness probes, resource requests/limits, and rolling update strategy for stateless application Deployments. Do not autoscale MongoDB as a stateless workload.
3. Add HPA for selected app services and verify metrics-server/metrics API and resource requests in the cluster. HPA requires metrics; merely setting `replicaCount: 2` is not autoscaling. Decide separately whether cluster node autoscaling is in scope.
4. Configure monitoring/logging (for example AWS CloudWatch Observability on EKS, or an explicitly chosen Prometheus/Grafana stack) and capture dashboards/alerts. Avoid claiming a feature is deployed until its configuration and health are verified.
5. Update Jenkins to use short-lived AWS role credentials; build/test, push immutable image tags, deploy through Helm to separate `dev`, `uat`, and `prod` namespaces with environment-specific non-secret values and external Secrets; wait for rollouts; run smoke tests; and expose an approval gate for promotion to production.
6. Add failure handling and rollback: record Helm revisions, stop promotion on failed health checks, and roll back only the failed namespace/release. Exercise this with a safe test release.

Before implementing Milestone 3, decide which monitoring stack to use and whether node autoscaling is included. Keep `terraform apply` behind a reviewed approval and configure remote Terraform state/locking before Jenkins manages infrastructure.
