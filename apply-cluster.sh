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

# Version numbers for Helm and Helm charts.
K8S_HELM_VERSION="v3.3.0"
K8S_INGRESS_NGINX_VERSION="4.2.1"

# Replace the template variables.
sed -e 's|{{CLUSTER}}|'${CLUSTER}'|g' \
    config/cluster/prometheus/prometheus.yml.template > \
    config/cluster/prometheus/prometheus.yml

# Prometheus config map.
kubectl create configmap prometheus-cluster-config \
    --from-file=config/cluster/prometheus \
    --dry-run="client" -o json | kubectl apply -f -

# Construct the per-project CLIENT_ID, CLIENT_SECRET and COOKIE_SECRET for OAuth.
export OAUTH_PROXY_CLIENT_ID=OAUTH_PROXY_CLIENT_ID_${PROJECT/-/_}
export OAUTH_PROXY_CLIENT_SECRET=OAUTH_PROXY_CLIENT_SECRET_${PROJECT/-/_}
export OAUTH_PROXY_COOKIE_SECRET=OAUTH_PROXY_COOKIE_SECRET_${PROJECT/-/_}

# Replace template variables in oauth2-proxy.yml.
sed -i -e 's|{{OAUTH_PROXY_CLIENT_ID}}|'${!OAUTH_PROXY_CLIENT_ID}'|g' \
    -e 's|{{OAUTH_PROXY_CLIENT_SECRET}}|'${!OAUTH_PROXY_CLIENT_SECRET}'|g' \
    -e 's|{{OAUTH_PROXY_COOKIE_SECRET}}|'${!OAUTH_PROXY_COOKIE_SECRET}'|g' \
    k8s/data-pipeline/deployments/oauth2-proxy.yml

# Additional k8s resources installed via Helm
#
# Download Helm
curl -O https://get.helm.sh/helm-${K8S_HELM_VERSION}-linux-amd64.tar.gz
tar -zxvf helm-${K8S_HELM_VERSION}-linux-amd64.tar.gz

# Add repos
./linux-amd64/helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
#./linux-amd64/helm repo add jetstack https://charts.jetstack.io

# Update local repos
./linux-amd64/helm repo update

# Install the NGINX ingress controller in the ingress-nginx namespace.
kubectl create namespace ingress-nginx --dry-run="client" -o json | kubectl apply -f -
./linux-amd64/helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --version ${K8S_INGRESS_NGINX_VERSION} \
  --values helm/data-pipeline/ingress-nginx/${PROJECT}.yml


# Install cert-manager.
#
# NOTE: for testing of cert-manager/certificates which might exhaust
# our API limits for LetsEncrypt's production ACME servers, please change the
# defaultIssuerName below to "letsencrypt-staging". Once your testing is done,
# change it back to "letsencrypt". LE staging ACME servers have much higher
# quotes/limits, and issue valid certificates, but ones which aren't trusted by
# most clients (browsers, etc.).
./linux-amd64/helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.8.0 \
  --set installCRDs=true \
  --set ingressShim.defaultIssuerKind=ClusterIssuer \
  --set ingressShim.defaultIssuerName=letsencrypt
  
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
