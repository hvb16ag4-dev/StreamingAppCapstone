
#!/bin/bash

# ==========================================
# Prometheus + Grafana Installation Script
# Kubernetes using Helm
# ==========================================

set -euo pipefail

NAMESPACE="monitoring"
RELEASE_NAME="monitoring"
CHART="prometheus-community/kube-prometheus-stack"

echo "======================================"
echo " Starting Monitoring Stack Installation"
echo "======================================"

# Step 1: Check prerequisites
echo "[1/6] Checking prerequisites..."

for cmd in helm kubectl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd is not installed."
        exit 1
    fi
done

# Step 2: Check Kubernetes connection
echo "[2/6] Checking Kubernetes cluster..."

kubectl cluster-info

# Step 3: Add Prometheus Helm repository
echo "[3/6] Adding Prometheus Helm repository..."

helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts

# Step 4: Update Helm repositories
echo "Updating Helm repositories..."

helm repo update

# Step 5: Search chart
echo "Searching kube-prometheus-stack chart..."

helm search repo "$CHART"

# Step 6: Create monitoring namespace
echo "[4/6] Creating monitoring namespace..."

kubectl create namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Step 7: Install Prometheus and Grafana
echo "[5/6] Installing Prometheus and Grafana..."

helm upgrade --install "$RELEASE_NAME" "$CHART" \
    --namespace "$NAMESPACE" \
    --set grafana.service.type=ClusterIP \
    --set prometheus.prometheusSpec.retention=2d \
    --set prometheus.prometheusSpec.resources.requests.cpu=200m \
    --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
    --set prometheus.prometheusSpec.resources.limits.memory=1Gi \
    --set grafana.resources.requests.cpu=100m \
    --set grafana.resources.requests.memory=256Mi \
    --set grafana.resources.limits.memory=512Mi \
    --wait \
    --timeout 10m

# Step 8: Verify installation
echo "[6/6] Verifying monitoring components..."

kubectl get pods -n "$NAMESPACE"
kubectl get services -n "$NAMESPACE"

echo "======================================"
echo " Monitoring Stack Installed Successfully!"
echo "======================================"

echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "Chart: $CHART"
