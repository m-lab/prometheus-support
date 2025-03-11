#!/bin/bash
#
# apply-cluster.sh applies the k8s cluster configuration to the currently
# configured cluster. This script may be safely run multiple times to load the
# most recent configurations.
#
# Example:
#
#   PROJECT=mlab-sandbox CLUSTER=prometheus-federation ./apply-cluster.sh

set -e
set -u
set -x

source config.sh

# Create the alertmanager-basicauth secret
echo "${AM_BASIC_AUTH_SECRET}" > alertmanager-basicauth.yaml
kubectl apply -f alertmanager-basicauth.yaml

# Replace the template variables.
sed -e 's|{{CLUSTER}}|'${CLUSTER}'|g' \
    -e 's|{{PROJECT}}|'${PROJECT}'|g' \
    config/${CLUSTER}/prometheus/prometheus.yml.template > \
    config/${CLUSTER}/prometheus/prometheus.yml

# Prometheus config map.
kubectl create configmap prometheus-cluster-config \
    --from-file=config/${CLUSTER}/prometheus \
    --dry-run="client" -o json | kubectl apply -f -

# Create the blackbox_exporter config ConfigMap
kubectl create configmap blackbox-config \
    --from-file=config/autojoin/blackbox \
    --dry-run="client" -o json | kubectl apply -f -

# Apply the bigquery exporter configurations.
kubectl create configmap bigquery-exporter-config \
    --from-file=config/autojoin/bigquery \
    --dry-run="client" -o json | kubectl apply -f -

kubectl create secret generic prometheus-auth \
    "--from-literal=auth=$(htpasswd -nb ${!PROM_AUTH_USER} ${!PROM_AUTH_PASS})"\
    --dry-run="client" -o json | kubectl apply -f -

kubectl create configmap script-exporter-config \
  --from-file=config/autojoin/script-exporter/script_exporter.yml \
  --dry-run="client" -o json | kubectl apply -f -

# This file should already exist in this location from the
# apply-global-prometheus.sh script, but it is duplicated here so that it is
# easier to understand where the file comes from.
echo "${MONITORING_SIGNER_KEY}" | base64 -d > /tmp/monitoring-signer-key.json
kubectl create secret generic script-exporter-secret \
  "--from-file=/tmp/monitoring-signer-key.json" \
  --dry-run="client" -o json | kubectl apply -f -

# Replace template variables in oauth2-proxy.yml.
sed -i -e 's|{{OAUTH_PROXY_CLIENT_ID}}|'${!OAUTH_PROXY_CLIENT_ID}'|g' \
    -e 's|{{OAUTH_PROXY_CLIENT_SECRET}}|'${!OAUTH_PROXY_CLIENT_SECRET}'|g' \
    -e 's|{{OAUTH_PROXY_COOKIE_SECRET}}|'${!OAUTH_PROXY_COOKIE_SECRET}'|g' \
    k8s/${CLUSTER}/deployments/oauth2-proxy.yml

# Additional k8s resources installed via Helm
#
# Install the NGINX ingress controller in the ingress-nginx namespace.
kubectl create namespace ingress-nginx --dry-run="client" -o json | kubectl apply -f -
./linux-amd64/helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --version ${K8S_INGRESS_NGINX_VERSION} \
  --values helm/${CLUSTER}/ingress-nginx/${PROJECT}.yml


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
