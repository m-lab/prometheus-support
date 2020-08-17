#!/bin/bash
#
# apply-cluster.sh applies the k8s cluster configuration to the currently
# configured cluster. This script may be safely run multiple times to load the
# most recent configurations.
#
# Example:
#
#   PROJECT=mlab-sandbox CLUSTER=prometheus-federation ./apply-cluster.sh

set -x
set -e
set -u

USAGE="PROJECT=<projectid> CLUSTER=<cluster> $0"
PROJECT=${PROJECT:?Please provide project id: $USAGE}
CLUSTER=${CLUSTER:?Please provide cluster name: $USAGE}

K8S_HELM_VERSION="v3.3.0"
K8S_INGRESS_NGINX_VERSION="2.11.2"

# Prometheus config map.
kubectl create configmap prometheus-cluster-config \
    --from-file=config/cluster/prometheus \
    --dry-run -o json | kubectl apply -f -


# Check for per-project template variables.
if [[ ! -f "k8s/${CLUSTER}/${PROJECT}.yml" ]] ; then
  echo "No template variables found for k8s/${CLUSTER}/${PROJECT}.yml"
  # This is not necessarily an error, so exit cleanly.
  exit 0
fi

# Apply templates
CFG=/tmp/${CLUSTER}-${PROJECT}.yml
kexpand expand --ignore-missing-keys k8s/${CLUSTER}/*/*.yml \
    -f k8s/${CLUSTER}/${PROJECT}.yml > ${CFG}
kubectl apply -f ${CFG}

#
# Additional k8s resources installed via Helm
#
# Download Helm
curl -O https://get.helm.sh/helm-${K8S_HELM_VERSION}-linux-amd64.tar.gz
tar -zxvf helm-${K8S_HELM_VERSION}-linux-amd64.tar.gz

# Install the NGINX ingress controller in the ingress-nginx namespace.
kubectl create namespace ingress-nginx --dry-run -o json | kubectl apply -f -
./linux-amd64/helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
./linux-amd64/helm repo update
./linux-amd64/helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --version ${K8S_INGRESS_NGINX_VERSION} \
  --values config/federation/ingress-nginx/helm-values-${PROJECT}.yml
