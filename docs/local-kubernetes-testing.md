# Local Kubernetes test before AWS

This guide deploys the current `feature_terraform` Helm chart to a local Kubernetes cluster before using EKS. Docker Desktop Kubernetes is the simplest path on Windows/WSL. Minikube is a suitable alternative. Neither method creates AWS resources.

The local Kubernetes test uses the same five app images built for Compose and pulls the official `mongo:6` image. It disables the chart's AWS ALB Ingress and uses `kubectl port-forward` for local browser/API access. It does not test S3 upload/playback or AWS IAM roles.

## One-command deployment helper

From the repository root, run:

```bash
chmod +x scripts/k8s-deploy.sh
./scripts/k8s-deploy.sh local
```

This checks Docker Desktop Kubernetes, rebuilds the four backend images and a frontend image with localhost API URLs, ensures the namespace and runtime Secret exist, upgrades the local Helm release, waits for Deployments/PVC readiness, starts managed port-forwards, and checks all five HTTP endpoints. Open `http://localhost:3000` for screenshots. The script reuses the existing JWT Secret and does not print its value.

When the port-forwards stop but the release still exists, run `./scripts/k8s-deploy.sh local` again; it reconciles the release and restarts the tunnels. Other helpers:

```bash
./scripts/k8s-deploy.sh status
./scripts/k8s-deploy.sh stop-local
```

`stop-local` only stops the managed port-forwards. To remove the local Helm release, run `helm uninstall streamingapp --namespace streamingapp`; removing the namespace also deletes its local MongoDB PVC/data.

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

Compose reads the ignored repository-root `.env` file. Helm/Kubernetes does **not** read that file; Kubernetes receives normal settings through Helm values and the JWT through a Kubernetes Secret.

For Compose/local image builds, create `.env` in the repository root with local-only values:

```ini
MONGO_DB=streamingapp
JWT_SECRET=<generate-a-unique-local-random-value>
CLIENT_URLS=http://localhost:3000
AWS_REGION=ap-south-1
AWS_S3_BUCKET=
AWS_CDN_URL=
STREAMING_PUBLIC_URL=http://localhost:3002
REACT_APP_AUTH_API_URL=http://localhost:3001/api
REACT_APP_STREAMING_API_URL=http://localhost:3002/api
REACT_APP_STREAMING_PUBLIC_URL=http://localhost:3002
REACT_APP_ADMIN_API_URL=http://localhost:3003/api/admin
REACT_APP_CHAT_API_URL=http://localhost:3004/api/chat
REACT_APP_CHAT_SOCKET_URL=http://localhost:3004
```

Generate a secret locally, then paste it into `.env` without sharing or capturing its value:

```bash
openssl rand -hex 32
```

Do not copy the AWS access-key placeholders from `.env.example`; leave AWS credentials and bucket/CDN values unset for this test. `.env` is ignored by Git. Without S3, browse/login/chat health can be tested, but uploading and playing S3-backed videos cannot.

## 3. Build images locally

From the repository root:

```bash
docker compose build auth streaming admin chat
docker compose pull mongo
docker image ls
```

With the current Compose project name, the four backend images are:

- `streamingappcapstone-auth:latest`
- `streamingappcapstone-streaming:latest`
- `streamingappcapstone-admin:latest`
- `streamingappcapstone-chat:latest`

Check `docker image ls` and edit the image names in [`helm/streamingapp/values-local.yaml.example`](../helm/streamingapp/values-local.yaml.example) if Compose used a different project prefix.

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

The example local values set local image names, single replicas, localhost CORS origins, and disable the AWS ALB Ingress. Keep the JWT out of this values file.

```bash
helm lint ./helm/streamingapp
helm template streamingapp ./helm/streamingapp \
  --namespace streamingapp \
  --values ./helm/streamingapp/values-local.yaml.example

kubectl create namespace streamingapp \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n streamingapp create secret generic streamingapp-runtime \
  --from-literal=jwt-secret="$(openssl rand -hex 32)" \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install streamingapp ./helm/streamingapp \
  --namespace streamingapp \
  --values ./helm/streamingapp/values-local.yaml.example \
  --wait --timeout 5m
```

The generated JWT is only in the local Kubernetes Secret. The chart composes each backend Mongo URI using the release's Mongo Service name; install as release `streamingapp` so it resolves to `streamingapp-mongo`.

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

Exercise registration/login and chat using two browser sessions. Catalogue metadata can be tested if seeded into MongoDB; video upload and playback require S3 and are intentionally out of scope here.

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

Only delete the namespace if the local MongoDB test data is disposable. Docker Compose containers are separate; stop those with `docker compose down` if they were also started.

## 6. Move from local Kubernetes to AWS

Once local Kubernetes passes, use the same chart but substitute ECR image URIs, configure approved IAM Identity Center access, give Terraform the approved trusted API CIDR, and create the runtime Secret in EKS. Install AWS Load Balancer Controller and the required storage provisioner/CSI driver before depending on ALB ingress and Mongo PVC provisioning. Review the Terraform plan and costs before applying. Do not copy local `.env`, local Kubernetes Secrets, or Docker credentials to AWS.

After an approved operator has separately provisioned the cluster, ECR repositories, ALB controller, and default EBS CSI StorageClass, the helper can build/tag/push app images and deploy them:

```bash
aws sso login --profile streamingapp
export AWS_PROFILE=streamingapp
export EXPECTED_AWS_ACCOUNT_ID=YOUR_APPROVED_ACCOUNT_ID
export TRUSTED_EKS_API_CIDR=YOUR_TRUSTED_PUBLIC_IP/32
export AWS_REGION=ap-south-1
export EKS_CLUSTER_NAME=streamingapp-eks
./scripts/k8s-deploy.sh aws
```

The script checks that the SSO/assumed-role identity matches the expected account, the cluster allows the supplied trusted CIDR, the five ECR repositories exist, the AWS Load Balancer Controller rollout is ready, and a default StorageClass exists. It asks for the literal confirmation `deploy` before it builds/pushes images and performs the Helm release. **It does not run `terraform apply`**; Terraform must be planned, reviewed, and applied separately. The AWS mode creates a generated JWT Kubernetes Secret only if one does not exist and waits for the ALB DNS name before updating CORS/public streaming URLs. It currently uses HTTP, not TLS. AWS resources incur costs.

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
