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
