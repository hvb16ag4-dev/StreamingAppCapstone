export AWS_PROFILE=HeroVired
export EXPECTED_AWS_ACCOUNT_ID=129373676098
export AWS_REGION=ap-south-1

export AWS_S3_BUCKET=streamingapp-uat-129373676098-ap-south-1
export APP_MEDIA_ROLE_ARN=arn:aws:iam::129373676098:role/streamingapp-uat-eks-media-access-role

export DEPLOY_ENV=uat
export EKS_CLUSTER_NAME=streamingapp-uat-eks
export TRUSTED_EKS_API_CIDR=106.222.231.243/32
export TRUSTED_EKS_API_CIDR=106.216.197.104/32
export HELM_VALUES_FILE=helm/streamingapp/values-uat.yaml
export UAT_ORIGIN=https://your-uat-domain.example


 load_balancer_controller_role_arn=arn:aws:iam::129373676098:role/streamingapp-uat-eks-alb-controller-role
 app_media_access_role_arn=arn:aws:iam::129373676098:role/streamingapp-uat-eks-media-access-role

cluster_endpoint = "https://F3109D72E8BDD574137D5801F3CBF5C3.gr7.ap-south-1.eks.amazonaws.com"
cluster_name = "streamingapp-uat-eks"

./scripts/k8s-deploy.sh aws


export AWS_S3_BUCKET="$(terraform output -raw media_bucket_name)"
export APP_MEDIA_ROLE_ARN="$(terraform output -raw app_media_access_role_arn)"

aws eks update-kubeconfig --profile "$AWS_PROFILE" --region "$AWS_REGION" --name streamingapp-uat-eks
kubectl get nodes
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller
kubectl get storageclass


kubectl -n streamingapp-uat get deployments,pods,services,pvc,ingress
kubectl -n streamingapp-uat rollout status deployment --all
kubectl -n streamingapp-uat describe ingress streamingapp-uat


helm template streamingapp-uat ./helm/streamingapp \
  --namespace streamingapp-uat \
  --values ./helm/streamingapp/values.yaml \
  --set-string awsRegion="$AWS_REGION" \
  --set-string services.auth.env.AWS_S3_BUCKET="$AWS_S3_BUCKET" \
  --set-string services.streaming.env.AWS_S3_BUCKET="$AWS_S3_BUCKET" \
  --set-string services.admin.env.AWS_S3_BUCKET="$AWS_S3_BUCKET" \
  --set-string objectStorage.bucket="$AWS_S3_BUCKET" \
  --set-string objectStorage.credentialsSecret="" \
  --set-string serviceAccount.name=streamingapp-uat-app \
  --set-string "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$APP_MEDIA_ROLE_ARN" \
  --set-string services.auth.env.CLIENT_URLS="$UAT_ORIGIN" \
  --set-string services.streaming.env.CLIENT_URLS="$UAT_ORIGIN" \
  --set-string services.admin.env.CLIENT_URLS="$UAT_ORIGIN" \
  --set-string services.chat.env.CLIENT_URLS="$UAT_ORIGIN" \
  --set-string services.streaming.env.STREAMING_PUBLIC_URL="$UAT_ORIGIN" \
  --set-string services.admin.env.STREAMING_PUBLIC_URL="$UAT_ORIGIN"

./scripts/k8s-deploy.sh aws

(Invoke-RestMethod https://checkip.amazonaws.com).Trim()

aws eks describe-cluster --name streamingapp-uat-eks --region ap-south-1 --profile HeroVired --query "cluster.resourcesVpcConfig.{public:endpointPublicAccess,private:endpointPrivateAccess,allowedCidrs:publicAccessCidrs}" --output table

aws eks describe-cluster --name streamingapp-uat-eks --region ap-south-1 --profile "$AWS_PROFILE" --query "cluster.accessConfig.authenticationMode" --output text

env | grep '^AWS_'
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
aws sso login --profile HeroVired
aws sts get-caller-identity --profile HeroVired

arn:aws:iam::129373676098:role/aws-reserved/sso.amazonaws.com/ap-south-1/AWSReservedSSO_AdministratorAccess_ebe8b963c934c1ac

curl -s https://checkip.amazonaws.com

aws sts get-caller-identity --profile "$AWS_PROFILE"
aws eks list-access-entries --cluster-name streamingapp-uat-eks --region ap-south-1 --profile "$AWS_PROFILE"

aws eks describe-cluster --name streamingapp-uat-eks --region ap-south-1 --profile "$AWS_PROFILE" --query "cluster.accessConfig.authenticationMode" --output text


printf 'TRUSTED_EKS_API_CIDR=%s\n' "$TRUSTED_EKS_API_CIDR"
curl -fsS https://checkip.amazonaws.com
aws eks describe-cluster --name streamingapp-uat-eks --region ap-south-1 --profile "$AWS_PROFILE" --query 'cluster.resourcesVpcConfig.publicAccessCidrs' --output text


---
export AWS_PROFILE=HeroVired
export AWS_REGION=ap-south-1
export EKS_CLUSTER_NAME=streamingapp-uat-eks
export IAM_ROLE_ARN=arn:aws:iam::129373676098:role/aws-reserved/sso.amazonaws.com/ap-south-1/AWSReservedSSO_AdministratorAccess_ebe8b963c934c1ac

aws eks update-cluster-config \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER_NAME" \
  --access-config authenticationMode=API_AND_CONFIG_MAP

aws eks wait cluster-active \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER_NAME"

aws eks describe-cluster \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER_NAME" \
  --query 'cluster.accessConfig.authenticationMode' \
  --output text

aws eks create-access-entry \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$IAM_ROLE_ARN" \
  --type STANDARD \
  --kubernetes-groups streamingapp-uat-deployer

aws eks describe-access-entry \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$IAM_ROLE_ARN"

kubectl create namespace streamingapp-uat --dry-run=client -o yaml | kubectl apply -f -

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: streamingapp-uat-prerequisite-reader
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: streamingapp-uat-prerequisite-reader
subjects:
  - kind: Group
    name: streamingapp-uat-deployer
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: streamingapp-uat-prerequisite-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: streamingapp-uat-namespace-reconciler
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    resourceNames: ["streamingapp-uat"]
    verbs: ["get", "patch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: streamingapp-uat-namespace-reconciler
subjects:
  - kind: Group
    name: streamingapp-uat-deployer
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: streamingapp-uat-namespace-reconciler
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: streamingapp-uat-controller-status-reader
  namespace: kube-system
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: streamingapp-uat-controller-status-reader
  namespace: kube-system
subjects:
  - kind: Group
    name: streamingapp-uat-deployer
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: streamingapp-uat-controller-status-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: streamingapp-uat-deployer
  namespace: streamingapp-uat
subjects:
  - kind: Group
    name: streamingapp-uat-deployer
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
EOF

aws eks update-kubeconfig \
  --profile "$AWS_PROFILE" \
  --region ap-south-1 \
  --name streamingapp-uat-eks

kubectl get nodes
kubectl get storageclass
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=30s
kubectl auth can-i create deployments -n streamingapp-uat

---

aws eks describe-cluster --name streamingapp-uat-eks --region ap-south-1 \
  --profile "$AWS_PROFILE" \
  --query 'cluster.accessConfig.authenticationMode' --output text

aws eks update-cluster-config --name streamingapp-uat-eks --region ap-south-1 \
  --profile "$AWS_PROFILE" \
  --access-config authenticationMode=API_AND_CONFIG_MAP

aws eks wait cluster-active --name streamingapp-uat-eks --region ap-south-1 \
  --profile "$AWS_PROFILE"


export IAM_ROLE_ARN=arn:aws:iam::129373676098:role/aws-reserved/sso.amazonaws.com/ap-south-1/AWSReservedSSO_AdministratorAccess_ebe8b963c934c1ac

aws eks create-access-entry --cluster-name streamingapp-uat-eks --region ap-south-1 \
  --profile "$AWS_PROFILE" --principal-arn "$IAM_ROLE_ARN" \
  --type STANDARD --kubernetes-groups streamingapp-uat-deployer

aws eks update-access-entry --cluster-name streamingapp-uat-eks --region ap-south-1 \
  --profile "$AWS_PROFILE" --principal-arn "$IAM_ROLE_ARN" \
  --kubernetes-groups streamingapp-uat-deployer


aws eks associate-access-policy --cluster-name streamingapp-uat-eks --region ap-south-1 \
  --profile "$AWS_PROFILE" --principal-arn "$IAM_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster




aws eks disassociate-access-policy --cluster-name streamingapp-uat-eks --region ap-south-1 \
  --profile "$AWS_PROFILE" --principal-arn "$IAM_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy

kubectl get nodes
kubectl auth can-i create deployments -n streamingapp-uat

---Recheck---
kubectl create serviceaccount aws-load-balancer-controller -n kube-system \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  eks.amazonaws.com/role-arn="$LBC_ROLE_ARN" --overwrite

helm repo add eks https://aws.github.io/eks-charts --force-update
helm repo update eks

helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --version 1.14.0 \
  --set clusterName=streamingapp-uat-eks \
  --set region=ap-south-1 \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl rollout status deployment/aws-load-balancer-controller \
  -n kube-system --timeout=5m
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
---recheck---
export LBC_ROLE_ARN='arn:aws:iam::129373676098:role/streamingapp-uat-eks-alb-controller-role'
export VPC_ID="$(AWS_PROFILE="$AWS_PROFILE" terraform -chdir=terraform output -raw vpc_id)"

kubectl create serviceaccount aws-load-balancer-controller -n kube-system \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  eks.amazonaws.com/role-arn="$LBC_ROLE_ARN" --overwrite

helm repo add eks https://aws.github.io/eks-charts --force-update
helm repo update eks

helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --version 1.14.0 \
  --set clusterName=streamingapp-uat-eks \
  --set region=ap-south-1 \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl rollout status deployment/aws-load-balancer-controller \
  -n kube-system --timeout=5m

---
aws eks list-addons --cluster-name streamingapp-uat-eks \
  --region ap-south-1 --profile "$AWS_PROFILE"

kubectl get pods -n kube-system | grep -i ebs
kubectl get storageclass


eksctl create iamserviceaccount \
  --cluster=streamingapp-uat-eks \
  --region=ap-south-1 \
  --namespace=kube-system \
  --name=ebs-csi-controller-sa \
  --role-name=streamingapp-uat-ebs-csi-role \
  --role-only \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2 \
  --approve

export EBS_CSI_ROLE_ARN='arn:aws:iam::129373676098:role/streamingapp-uat-ebs-csi-role'

aws eks create-addon \
  --cluster-name streamingapp-uat-eks \
  --region ap-south-1 \
  --profile "$AWS_PROFILE" \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn "$EBS_CSI_ROLE_ARN"

aws eks wait addon-active --cluster-name streamingapp-uat-eks \
  --region ap-south-1 --profile "$AWS_PROFILE" \
  --addon-name aws-ebs-csi-driver

kubectl get pods -n kube-system | grep ebs

---

ANSWERS

That should clear the script’s CIDR check. However, the kubectl credentials error is a separate issue and will likely stop deployment next: this cluster uses CONFIG_MAP authentication, so an administrator must map your IAM role in kube-system/aws-auth and grant the necessary Kubernetes permissions. list-access-entries won’t work unless the cluster’s authentication mode is changed.

Ask someone who already has cluster-admin access to add your IAM role to kube-system/aws-auth and grant the necessary RBAC permissions. Alternatively, an AWS administrator can deliberately migrate the cluster to API_AND_CONFIG_MAP and use EKS access entries; that’s a cluster-level change, so don’t switch modes just to make list-access-entries work. The repository’s Terraform setup doesn’t configure operator access entries.

Confirm the identity is in the expected UAT account. If its IAM role isn’t listed—or lacks an appropriate access policy—ask the UAT account administrator to add an EKS access entry for the IAM role behind your profile (not the STS assumed-role session ARN) and grant only the needed permissions. Listing nodes requires cluster-scoped access.

If it differs: add the current IP as a /32 to cluster_public_access_cidrs in terraform/environments/uat.tfvars, then review and apply the UAT Terraform plan. Keep the existing trusted addresses; don’t use 0.0.0.0/0.
If it matches: the timeout suggests a network path issue, such as a VPN, proxy, or firewall blocking outbound TCP 443. Check with your network administrator or try an approved network.

Ask the cluster administrator—or use the AWS role that created the cluster—to map your IAM role there and grant the needed Kubernetes RBAC permissions. For kubectl get nodes, that means cluster-scoped permission to read nodes; app deployment permissions can be scoped to the app namespace. Avoid granting system:masters unless you actually need full cluster-admin access.

ERRORS

abhis@Bharathgift MINGW64 ~/Harika/CapstoneProject4_EndToEnd/NOV/StreamingAppCapstone ((874455b...))
$ ./scripts/k8s-deploy.sh aws
Updated context arn:aws:eks:ap-south-1:129373676098:cluster/streamingapp-uat-eks in C:\Users\abhis\.kube\config
NAME                                          STATUS   ROLES    AGE   VERSION
ip-106-222-0-22.ap-south-1.compute.internal   Ready    <none>   89m   v1.37.1-eks-9adbfea
Error from server (NotFound): deployments.apps "aws-load-balancer-controller" not found
ERROR: Install and verify the AWS Load Balancer Controller and IRSA service account before deployment

ERRORS

abhis@Bharathgift MINGW64 ~/Harika/CapstoneProject4_EndToEnd/NOV/StreamingAppCapstone ((874455b...))
$ kubectl create namespace streamingapp-uat --dry-run=client -o yaml | kubectl apply -f -
Error from server (Forbidden): error when retrieving current configuration of:
Resource: "/v1, Resource=namespaces", GroupVersionKind: "/v1, Kind=Namespace"
Name: "streamingapp-uat", Namespace: ""
from server for: "STDIN": namespaces "streamingapp-uat" is forbidden: User "arn:aws:sts::129373676098:assumed-role/AWSReservedSSO_AdministratorAccess_ebe8b963c934c1ac/HarikaMadabathula" cannot get resource "namespaces" in API group "" in the namespace "streamingapp-uat"

ERRORS

abhis@Bharathgift MINGW64 ~/Harika/CapstoneProject4_EndToEnd/NOV/StreamingAppCapstone ((874455b...))
$ ./scripts/k8s-deploy.sh aws
ERROR: TRUSTED_EKS_API_CIDR is not an allowed public API CIDR on this cluster

ERRORS

abhis@Bharathgift MINGW64 ~/Harika/CapstoneProject4_EndToEnd/NOV/StreamingAppCapstone ((874455b...))
$ kubectl get nodes
E1123 17:53:43.267226   11300 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://2E002DD4827D6D22DB340B7EFC6A40DA.gr7.ap-south-1.eks.amazonaws.com/api?timeout=32s\": dial tcp 15.206.61.250:443: i/o timeout"


ERRORS


abhis@Bharathgift MINGW64 ~/Harika/CapstoneProject4_EndToEnd/NOV/StreamingAppCapstone ((874455b...))
$ aws eks update-kubeconfig --profile "$AWS_PROFILE" --region "$AWS_REGION" --name streamingapp-uat-eks
Updated context arn:aws:eks:ap-south-1:129373676098:cluster/streamingapp-uat-eks in C:\Users\abhis\.kube\config

abhis@Bharathgift MINGW64 ~/Harika/CapstoneProject4_EndToEnd/NOV/StreamingAppCapstone ((874455b...))
$ kubectl get nodes
E1123 17:59:45.506279   27800 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: the server has asked for the client to provide credentials"


ERRORS
abhis@Bharathgift MINGW64 ~/Harika/CapstoneProject4_EndToEnd/NOV/StreamingAppCapstone ((874455b...))
$ aws eks list-access-entries --cluster-name streamingapp-uat-eks --region ap-south-1 --profile "$AWS_PROFILE"

aws: [ERROR]: An error occurred (InvalidRequestException) when calling the ListAccessEntries operation: The cluster's authentication mode must be set to one of [API, API_AND_CONFIG_MAP] to perform this operation.

