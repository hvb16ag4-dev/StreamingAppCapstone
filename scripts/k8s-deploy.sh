#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RELEASE="${HELM_RELEASE:-streamingapp}"
NAMESPACE="${K8S_NAMESPACE:-streamingapp}"
LOCAL_VALUES="${LOCAL_HELM_VALUES:-helm/streamingapp/values-local.yaml.example}"
PID_DIR="$ROOT_DIR/.local-k8s"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ensure_namespace() {
  kubectl --context "$KUBE_CONTEXT" create namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl --context "$KUBE_CONTEXT" apply -f -
}

ensure_runtime_secret() {
  local context="$1"
  local secret_file

  if kubectl --context "$context" --namespace "$NAMESPACE" \
    get secret streamingapp-runtime >/dev/null 2>&1; then
    printf 'Using existing Kubernetes Secret %s/streamingapp-runtime\n' "$NAMESPACE"
    return
  fi

  secret_file="$(mktemp)"
  chmod 600 "$secret_file"
  trap 'rm -f "$secret_file"' RETURN
  openssl rand -hex 32 > "$secret_file"
  kubectl --context "$context" --namespace "$NAMESPACE" create secret generic \
    streamingapp-runtime --from-file="jwt-secret=$secret_file"
  rm -f "$secret_file"
  trap - RETURN
  printf 'Created Kubernetes Secret %s/streamingapp-runtime (value not displayed)\n' "$NAMESPACE"
}

ensure_local_aws_secret() {
  local context="$1"
  local secret_dir
  local source_account
  local credentials
  local access_key_id
  local secret_access_key
  local session_token

  [[ -n "${AWS_PROFILE:-}" ]] || die "Set AWS_PROFILE to the UAT IAM Identity Center profile"
  [[ -n "${EXPECTED_AWS_ACCOUNT_ID:-}" ]] || die "Set EXPECTED_AWS_ACCOUNT_ID to the UAT account ID"
  [[ -n "${LOCAL_S3_ROLE_ARN:-}" ]] || die "Set LOCAL_S3_ROLE_ARN to the Terraform local_dev_media_access_role_arn output"
  [[ -n "${AWS_S3_BUCKET:-}" ]] || die "Set AWS_S3_BUCKET to the Terraform local_dev_media_bucket_name output"
  AWS_REGION="${AWS_REGION:-ap-south-1}"

  source_account="$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)" \
    || die "Unable to authenticate with AWS_PROFILE; run aws sso login first"
  [[ "$source_account" == "$EXPECTED_AWS_ACCOUNT_ID" ]] \
    || die "AWS_PROFILE is authenticated to a different account than EXPECTED_AWS_ACCOUNT_ID"
  credentials="$(aws sts assume-role --profile "$AWS_PROFILE" \
    --role-arn "$LOCAL_S3_ROLE_ARN" \
    --role-session-name streamingapp-local-dev \
    --duration-seconds 3600 \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)" || die "Unable to assume the restricted local DEV S3 role"
  IFS=$'\t' read -r access_key_id secret_access_key session_token <<< "$credentials"
  [[ -n "$access_key_id" && -n "$secret_access_key" && -n "$session_token" ]] \
    || die "AWS returned incomplete temporary credentials"
  AWS_ACCESS_KEY_ID="$access_key_id" \
    AWS_SECRET_ACCESS_KEY="$secret_access_key" \
    AWS_SESSION_TOKEN="$session_token" \
    aws s3api head-bucket --bucket "$AWS_S3_BUCKET" --region "$AWS_REGION" \
    || die "The assumed local DEV role cannot access AWS_S3_BUCKET"

  secret_dir="$(mktemp -d)"
  chmod 700 "$secret_dir"
  trap 'rm -rf "$secret_dir"' RETURN
  printf '%s' "$access_key_id" > "$secret_dir/access-key-id"
  printf '%s' "$secret_access_key" > "$secret_dir/secret-access-key"
  printf '%s' "$session_token" > "$secret_dir/session-token"
  kubectl --context "$context" --namespace "$NAMESPACE" create secret generic \
    streamingapp-object-store \
    --from-file="access-key-id=$secret_dir/access-key-id" \
    --from-file="secret-access-key=$secret_dir/secret-access-key" \
    --from-file="session-token=$secret_dir/session-token" \
    --dry-run=client -o yaml | kubectl --context "$context" --namespace "$NAMESPACE" \
      apply --server-side --force-conflicts -f -
  rm -rf "$secret_dir"
  trap - RETURN
  printf 'Updated Kubernetes Secret %s/streamingapp-object-store with short-lived role credentials (values not displayed)\n' "$NAMESPACE"
}

check_local_endpoints() {
  local endpoint
  local code
  local endpoints=(
    "http://localhost:3000|frontend"
    "http://localhost:3001/health|auth"
    "http://localhost:3002/api/health|streaming"
    "http://localhost:3003/api/health|admin"
    "http://localhost:3004/api/health|chat"
  )

  for endpoint in "${endpoints[@]}"; do
    local url="${endpoint%%|*}"
    local name="${endpoint##*|}"
    local attempt
    code=""
    for attempt in {1..10}; do
      if code="$(curl --max-time 10 -sS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)" \
        && [[ "$code" == "200" ]]; then
        break
      fi
      sleep 1
    done
    [[ "$code" == "200" ]] \
      || die "$name did not return HTTP 200 at $url after 10 attempts (last status: ${code:-no response})"
    printf '%-10s HTTP %s  %s\n' "$name" "$code" "$url"
  done
}

start_port_forward() {
  local service="$1"
  local local_port="$2"
  local remote_port="$3"
  local pid_file="$PID_DIR/$service.pid"
  local log_file="$PID_DIR/$service.log"
  local attempt
  local pid

  if [[ -f "$pid_file" ]]; then
    pid="$(<"$pid_file")"
    if kill -0 "$pid" 2>/dev/null; then
      local command_line
      command_line="$(ps -p "$pid" -o args= 2>/dev/null || true)"
      if [[ "$command_line" == *"port-forward"* && "$command_line" == *"service/$service"* ]]; then
        return
      fi
    fi
    rm -f "$pid_file"
  fi

  nohup kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    port-forward --address 127.0.0.1 "service/$service" \
    "$local_port:$remote_port" >"$log_file" 2>&1 < /dev/null &
  printf '%s\n' "$!" > "$pid_file"

  for attempt in {1..30}; do
    if grep -q "Forwarding from 127.0.0.1:$local_port" "$log_file" 2>/dev/null; then
      printf 'Forwarding localhost:%s -> %s:%s\n' "$local_port" "$service" "$remote_port"
      return
    fi
    pid="$(<"$pid_file")"
    kill -0 "$pid" 2>/dev/null || {
      cat "$log_file" >&2
      die "Port-forward for $service stopped unexpectedly"
    }
    sleep 1
  done

  cat "$log_file" >&2
  die "Timed out waiting for port-forward for $service"
}

stop_local() {
  local pid_file
  local pid
  local service
  local command_line

  for pid_file in "$PID_DIR"/*.pid; do
    [[ -f "$pid_file" ]] || continue
    pid="$(<"$pid_file")"
    service="$(basename "$pid_file" .pid)"
    command_line=""
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      command_line="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    fi
    if [[ "$command_line" == *"port-forward"* && "$command_line" == *"service/$service"* ]]; then
      kill "$pid"
      printf 'Stopped port-forward PID %s\n' "$pid"
    fi
    rm -f "$pid_file"
  done
}

forward_local() {
  KUBE_CONTEXT="${KUBE_CONTEXT:-docker-desktop}"
  require_command kubectl
  require_command curl
  kubectl --context "$KUBE_CONTEXT" cluster-info >/dev/null \
    || die "Kubernetes context '$KUBE_CONTEXT' is not reachable"

  mkdir -p "$PID_DIR"
  start_port_forward "$RELEASE-frontend" 3000 80
  start_port_forward "$RELEASE-auth" 3001 3001
  start_port_forward "$RELEASE-streaming" 3002 3002
  start_port_forward "$RELEASE-admin" 3003 3003
  start_port_forward "$RELEASE-chat" 3004 3004
  check_local_endpoints
}

refresh_local_aws_credentials() {
  KUBE_CONTEXT="${KUBE_CONTEXT:-docker-desktop}"
  require_command aws
  require_command kubectl
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    get deployment "$RELEASE-admin" "$RELEASE-streaming" >/dev/null \
    || die "Local app deployments are not installed"
  ensure_local_aws_secret "$KUBE_CONTEXT"
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    rollout restart deployment/"$RELEASE-admin" deployment/"$RELEASE-streaming"
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    rollout status deployment/"$RELEASE-admin" --timeout=5m
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    rollout status deployment/"$RELEASE-streaming" --timeout=5m
}

build_local_images() {
  IMAGE_PREFIX="$image_prefix" IMAGE_TAG="$image_tag" \
    docker compose build auth streaming admin chat
  docker pull mongo:6
  docker build -t streamingapp-frontend:k8s-local \
    --build-arg REACT_APP_AUTH_API_URL=http://localhost:3001/api \
    --build-arg REACT_APP_STREAMING_API_URL=http://localhost:3002/api \
    --build-arg REACT_APP_STREAMING_PUBLIC_URL=http://localhost:3002 \
    --build-arg REACT_APP_ADMIN_API_URL=http://localhost:3003/api/admin \
    --build-arg REACT_APP_CHAT_API_URL=http://localhost:3004/api/chat \
    --build-arg REACT_APP_CHAT_SOCKET_URL=http://localhost:3004 \
    ./frontend
}

deploy_local() {
  local image_prefix="${IMAGE_PREFIX:-streamingappcapstone}"
  local image_tag="${IMAGE_TAG:-latest}"

  KUBE_CONTEXT="${KUBE_CONTEXT:-docker-desktop}"
  require_command docker
  require_command kubectl
  require_command helm
  require_command curl
  require_command openssl
  require_command aws
  [[ -f "$LOCAL_VALUES" ]] || die "Local values file not found: $LOCAL_VALUES"
  docker info >/dev/null || die "Docker engine is not available"
  kubectl config get-contexts "$KUBE_CONTEXT" -o name | grep -Fxq "$KUBE_CONTEXT" \
    || die "Kubernetes context '$KUBE_CONTEXT' is unavailable"
  kubectl --context "$KUBE_CONTEXT" cluster-info >/dev/null \
    || die "Kubernetes context '$KUBE_CONTEXT' is not reachable"

  printf 'Deploying local release %s to namespace %s using context %s\n' \
    "$RELEASE" "$NAMESPACE" "$KUBE_CONTEXT"
  build_local_images
  ensure_namespace
  ensure_runtime_secret "$KUBE_CONTEXT"
  ensure_local_aws_secret "$KUBE_CONTEXT"
  helm upgrade --install "$RELEASE" ./helm/streamingapp \
    --kube-context "$KUBE_CONTEXT" \
    --namespace "$NAMESPACE" \
    --values "$LOCAL_VALUES" \
    --set-string "services.auth.image=$image_prefix-auth:$image_tag" \
    --set-string "services.streaming.image=$image_prefix-streaming:$image_tag" \
    --set-string "services.admin.image=$image_prefix-admin:$image_tag" \
    --set-string "services.chat.image=$image_prefix-chat:$image_tag" \
    --set-string "awsRegion=$AWS_REGION" \
    --set-string "services.streaming.env.AWS_S3_BUCKET=$AWS_S3_BUCKET" \
    --set-string "services.admin.env.AWS_S3_BUCKET=$AWS_S3_BUCKET" \
    --set-string "objectStorage.bucket=$AWS_S3_BUCKET" \
    --set-string "objectStorage.endpoint=" \
    --set-string "objectStorage.forcePathStyle=false" \
    --set-string "objectStorage.credentialsSecret=streamingapp-object-store" \
    --wait --timeout 5m

  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    rollout restart deployment/"$RELEASE-admin" deployment/"$RELEASE-streaming"
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    wait --for=condition=Available deployment --all --timeout=5m
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    rollout status deployment/"$RELEASE-admin" --timeout=5m
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    rollout status deployment/"$RELEASE-streaming" --timeout=5m
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    wait --for=jsonpath='{.status.phase}'=Bound "pvc/$RELEASE-mongo-data" --timeout=3m

  mkdir -p "$PID_DIR"
  start_port_forward "$RELEASE-frontend" 3000 80
  start_port_forward "$RELEASE-auth" 3001 3001
  start_port_forward "$RELEASE-streaming" 3002 3002
  start_port_forward "$RELEASE-admin" 3003 3003
  start_port_forward "$RELEASE-chat" 3004 3004

  printf '\nDeployment summary:\n'
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    get deployments,pods,services,pvc
  printf '\nEndpoint checks:\n'
  check_local_endpoints
  printf '\nOpen http://localhost:3000 for the app and screenshots.\n'
  printf 'To stop the local access tunnels: %s stop-local\n' "$0"
  printf 'The Kubernetes release remains installed until explicitly uninstalled.\n'
}

deploy_aws() {
  local deploy_env
  local project_name
  local repository_prefix
  local app_service_account_name
  local caller_arn
  local account_id
  local cluster_cidrs
  local registry
  local image_tag
  local local_image_prefix
  local local_image_tag
  local image
  local ingress_hostname=""
  local attempt
  local secret_file

  deploy_env="${DEPLOY_ENV:-uat}"
  [[ "$deploy_env" == "uat" || "$deploy_env" == "prod" ]] \
    || die "DEPLOY_ENV must be uat or prod; dev is the local Docker Desktop environment"
  project_name="${PROJECT_NAME:-streamingapp}"
  repository_prefix="${ECR_REPOSITORY_PREFIX:-${project_name}-${deploy_env}}"
  app_service_account_name="${APP_SERVICE_ACCOUNT_NAME:-${project_name}-${deploy_env}-app}"
  RELEASE="${HELM_RELEASE:-${project_name}-${deploy_env}}"
  NAMESPACE="${K8S_NAMESPACE:-${project_name}-${deploy_env}}"

  require_command aws
  require_command docker
  require_command kubectl
  require_command helm
  require_command openssl
  [[ -n "${AWS_PROFILE:-}" ]] || die "Set AWS_PROFILE to the approved IAM Identity Center profile"
  [[ -n "${EXPECTED_AWS_ACCOUNT_ID:-}" ]] || die "Set EXPECTED_AWS_ACCOUNT_ID to the approved account ID"
  [[ -n "${TRUSTED_EKS_API_CIDR:-}" ]] || die "Set TRUSTED_EKS_API_CIDR to the approved EKS API client CIDR"
  [[ "$TRUSTED_EKS_API_CIDR" != "0.0.0.0/0" ]] || die "Do not expose the EKS API to 0.0.0.0/0"
  [[ -n "${AWS_S3_BUCKET:-}" ]] || die "Set AWS_S3_BUCKET to this account/environment's Terraform media_bucket_name output"
  [[ -n "${APP_MEDIA_ROLE_ARN:-}" ]] || die "Set APP_MEDIA_ROLE_ARN to this account/environment's Terraform app_media_access_role_arn output"

  AWS_REGION="${AWS_REGION:-ap-south-1}"
  EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-${project_name}-${deploy_env}-eks}"
  caller_arn="$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Arn --output text)"
  [[ "$caller_arn" != *":user/"* ]] \
    || die "Current AWS credentials are an IAM user. Configure the approved short-lived IAM Identity Center/assumed-role profile."
  account_id="$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)"
  [[ "$account_id" == "$EXPECTED_AWS_ACCOUNT_ID" ]] \
    || die "Authenticated account does not match EXPECTED_AWS_ACCOUNT_ID"
  cluster_cidrs="$(aws eks describe-cluster --profile "$AWS_PROFILE" --region "$AWS_REGION" \
    --name "$EKS_CLUSTER_NAME" \
    --query 'cluster.resourcesVpcConfig.publicAccessCidrs' --output text)" \
    || die "EKS cluster not found. Review and apply Terraform separately before running this script."
  grep -Fxq "$TRUSTED_EKS_API_CIDR" <<< "$(tr '\t' '\n' <<< "$cluster_cidrs")" \
    || die "TRUSTED_EKS_API_CIDR is not an allowed public API CIDR on this cluster"

  registry="$account_id.dkr.ecr.$AWS_REGION.amazonaws.com"
  for image in auth streaming admin chat frontend; do
    aws ecr describe-repositories --profile "$AWS_PROFILE" --region "$AWS_REGION" \
      --repository-names "$repository_prefix-$image" >/dev/null \
      || die "ECR repository $repository_prefix-$image not found; provision it before deployment"
  done

  aws eks update-kubeconfig --profile "$AWS_PROFILE" --region "$AWS_REGION" \
    --name "$EKS_CLUSTER_NAME"
  KUBE_CONTEXT="$(kubectl config current-context)"
  kubectl --context "$KUBE_CONTEXT" get nodes
  kubectl --context "$KUBE_CONTEXT" -n kube-system rollout status \
    deployment/aws-load-balancer-controller --timeout=5m \
    || die "Install and verify the AWS Load Balancer Controller and IRSA service account before deployment"
  kubectl --context "$KUBE_CONTEXT" get storageclass \
    -o jsonpath='{range .items[*]}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}{end}' \
    | grep -Fxq true \
    || die "No default StorageClass found; configure a supported EBS CSI StorageClass for the Mongo PVC"

  printf 'About to build and push five images to %s, then deploy to EKS cluster %s in %s.\n' \
    "$registry" "$EKS_CLUSTER_NAME" "$AWS_REGION"
  printf 'This does NOT run terraform apply. AWS resources and data may incur cost.\n'
  read -r -p "Type deploy to continue: " confirmation
  [[ "$confirmation" == "deploy" ]] || die "AWS deployment cancelled"

  image_tag="${IMAGE_TAG:-$(git rev-parse --short HEAD)-$(date -u +%Y%m%d%H%M%S)}"
  local_image_prefix="${IMAGE_PREFIX:-streamingappcapstone}"
  local_image_tag="${LOCAL_IMAGE_TAG:-latest}"
  IMAGE_PREFIX="$local_image_prefix" IMAGE_TAG="$local_image_tag" \
    docker compose build auth streaming admin chat
  docker build -t "streamingapp-frontend:aws-$image_tag" \
    --build-arg REACT_APP_AUTH_API_URL=/api \
    --build-arg REACT_APP_STREAMING_API_URL=/api \
    --build-arg REACT_APP_STREAMING_PUBLIC_URL=/ \
    --build-arg REACT_APP_ADMIN_API_URL=/api/admin \
    --build-arg REACT_APP_CHAT_API_URL=/api/chat \
    --build-arg REACT_APP_CHAT_SOCKET_URL=/ \
    ./frontend

  aws ecr get-login-password --profile "$AWS_PROFILE" --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$registry"
  for image in auth streaming admin chat; do
    docker tag "$local_image_prefix-$image:$local_image_tag" "$registry/$repository_prefix-$image:$image_tag"
    docker push "$registry/$repository_prefix-$image:$image_tag"
  done
  docker tag "streamingapp-frontend:aws-$image_tag" "$registry/$repository_prefix-frontend:$image_tag"
  docker push "$registry/$repository_prefix-frontend:$image_tag"

  ensure_namespace
  if ! kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    get secret streamingapp-runtime >/dev/null 2>&1; then
    secret_file="$(mktemp)"
    chmod 600 "$secret_file"
    trap 'rm -f "$secret_file"' RETURN
    openssl rand -hex 32 > "$secret_file"
    kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" create secret generic \
      streamingapp-runtime --from-file="jwt-secret=$secret_file"
    rm -f "$secret_file"
    trap - RETURN
  fi

  local helm_args=(
    --kube-context "$KUBE_CONTEXT"
    --namespace "$NAMESPACE"
    --set-string "services.auth.image=$registry/$repository_prefix-auth:$image_tag"
    --set-string "services.streaming.image=$registry/$repository_prefix-streaming:$image_tag"
    --set-string "services.admin.image=$registry/$repository_prefix-admin:$image_tag"
    --set-string "services.chat.image=$registry/$repository_prefix-chat:$image_tag"
    --set-string "services.frontend.image=$registry/$repository_prefix-frontend:$image_tag"
    --set-string "awsRegion=$AWS_REGION"
    --set-string "services.streaming.env.AWS_S3_BUCKET=$AWS_S3_BUCKET"
    --set-string "services.admin.env.AWS_S3_BUCKET=$AWS_S3_BUCKET"
    --set-string "objectStorage.bucket=$AWS_S3_BUCKET"
    --set-string "objectStorage.endpoint="
    --set-string "objectStorage.forcePathStyle=false"
    --set-string "objectStorage.credentialsSecret="
    --set-string "serviceAccount.name=$app_service_account_name"
    --set-string "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$APP_MEDIA_ROLE_ARN"
  )
  if [[ -n "${HELM_VALUES_FILE:-}" ]]; then
    helm_args+=(--values "$HELM_VALUES_FILE")
  fi
  helm upgrade --install "$RELEASE" ./helm/streamingapp "${helm_args[@]}" \
    --wait --timeout 10m

  for attempt in {1..60}; do
    ingress_hostname="$(kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
      get ingress "$RELEASE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    [[ -n "$ingress_hostname" ]] && break
    sleep 10
  done
  [[ -n "$ingress_hostname" ]] \
    || die "Ingress has no ALB hostname yet; inspect kubectl describe ingress and controller logs"

  helm upgrade "$RELEASE" ./helm/streamingapp "${helm_args[@]}" \
    --set-string "services.auth.env.CLIENT_URLS=http://$ingress_hostname" \
    --set-string "services.streaming.env.CLIENT_URLS=http://$ingress_hostname" \
    --set-string "services.admin.env.CLIENT_URLS=http://$ingress_hostname" \
    --set-string "services.chat.env.CLIENT_URLS=http://$ingress_hostname" \
    --set-string "services.streaming.env.STREAMING_PUBLIC_URL=http://$ingress_hostname" \
    --set-string "services.admin.env.STREAMING_PUBLIC_URL=http://$ingress_hostname" \
    --wait --timeout 10m

  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    wait --for=condition=Available deployment --all --timeout=10m
  printf 'AWS deployment complete. Environment: %s; image tag: %s\nIngress: http://%s\n' \
    "$deploy_env" "$image_tag" "$ingress_hostname"
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    get deployments,pods,services,pvc,ingress
}

status_local() {
  KUBE_CONTEXT="${KUBE_CONTEXT:-docker-desktop}"
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    get deployments,pods,services,pvc
  check_local_endpoints
}

usage() {
  cat <<'EOF'
Usage:
  scripts/k8s-deploy.sh local       Build/deploy to local Kubernetes using the UAT S3 role; start port-forwards
  scripts/k8s-deploy.sh forward-local  Start local port-forwards and check app endpoints
  scripts/k8s-deploy.sh refresh-local-aws-credentials  Refresh the 1-hour local AWS session
  scripts/k8s-deploy.sh status      Show local release and test its endpoints
  scripts/k8s-deploy.sh stop-local  Stop only the managed local port-forwards
  scripts/k8s-deploy.sh aws         Push images and deploy to an already-provisioned EKS cluster

AWS mode requires AWS_PROFILE, EXPECTED_AWS_ACCOUNT_ID, and TRUSTED_EKS_API_CIDR.
It never runs Terraform apply and requires typing "deploy" before pushing images.
Local mode additionally requires AWS_PROFILE, EXPECTED_AWS_ACCOUNT_ID, AWS_S3_BUCKET,
and LOCAL_S3_ROLE_ARN for short-lived UAT bucket-scoped credentials.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

case "${1:-}" in
  local)
    deploy_local
    ;;
  status)
    status_local
    ;;
  forward-local)
    forward_local
    ;;
  refresh-local-aws-credentials)
    refresh_local_aws_credentials
    ;;
  stop-local)
    stop_local
    ;;
  aws)
    deploy_aws
    ;;
  *)
    usage
    exit 2
    ;;
esac
