#!/bin/bash
#
# apply-global-prometheus.sh applies the global-prometheus configuration to the
# currently configured cluster. This script may be safely run multiple times to
# load the most recent configurations.
#
# If a config file (config/*) changes, the pod does not automatically restart
# when the configmap for that config file is updated. You must manually delete
# the pod, and kubernetes will recreate it with the new config.
#
# Example:
#
#   PROJECT=mlab-sandbox \
#     CLUSTER=prometheus-federation ./apply-global-prometheus.sh

set -x
set -e
set -u

# Get project and cluster from the environment.

USAGE="PROJECT=<projectid> CLUSTER=<cluster> $0"
PROJECT=${PROJECT:?Please provide project id: $USAGE}
CLUSTER=${CLUSTER:?Please provide cluster name: $USAGE}

export GRAFANA_DOMAIN=status-${PROJECT}.measurementlab.net
export ALERTMANAGER_URL=http://status-${PROJECT}.measurementlab.net:9093

# Roles.
kubectl apply -f "k8s/${PROJECT}/${CLUSTER}/roles"

# Deployent dependencies.
kubectl apply -f "k8s/${PROJECT}/${CLUSTER}/persistentvolumes"

# Services.
kubectl apply -f "k8s/${PROJECT}/${CLUSTER}/services"

# Config maps and Secrets

## Blackbox exporter.
kubectl create configmap blackbox-config \
    --from-file=config/federation/blackbox \
    --dry-run -o json | kubectl apply -f -

## Prometheus
kubectl create configmap prometheus-federation-config \
    --from-literal=gcloud-project=${PROJECT} \
    --from-file=config/federation/prometheus \
    --dry-run -o json | kubectl apply -f -

## Grafana
kubectl create configmap grafana-config \
    --from-file=config/federation/grafana \
    --dry-run -o json | kubectl apply -f -

# Keep the password a secret.
set +x
# It does not really matter what the admin password is.
export GRAFANA_PASSWORD=$( echo $RANDOM | md5sum | awk '{print $1}' )
kubectl create secret generic grafana-secrets \
    "--from-literal=admin-password=${GRAFANA_PASSWORD}" \
    --dry-run -o json | kubectl apply -f -
set -x


GF_CLIENT_SECRET_NAME=GF_AUTH_GOOGLE_CLIENT_SECRET_${PROJECT/-/_}
GF_CLIENT_ID_NAME=GF_AUTH_GOOGLE_CLIENT_ID_${PROJECT/-/_}
# TODO: kubectl v1.7  supports --from-env-file=
kubectl create configmap grafana-env \
    "--from-literal=domain=${GRAFANA_DOMAIN}" \
    "--from-literal=gf_auth_google_client_secret=${!GF_CLIENT_SECRET_NAME}" \
    "--from-literal=gf_auth_google_client_id=${!GF_CLIENT_ID_NAME}" \
    --dry-run -o json | kubectl apply -f -


## Alertmanager
# TODO: enable storing slack channels as secrets and generating the config.yml
# Check to see if the alertmanager-config already exists. Do nothing if so.
AM_CONFIG=$( kubectl get configmaps \
    alertmanager-config --output=jsonpath={.metadata.name} )
if [[ -z "${AM_CONFIG}" ]] ; then
  # Create a default configuration without actual values.
  cp config/federation/alertmanager/config.yml.template \
      config/federation/alertmanager/config.yml

  # Create a new configmap.
  kubectl create configmap alertmanager-config \
      --from-file=config/federation/alertmanager \
      --dry-run -o json | kubectl apply -f -
fi

if [[ -n "${ALERTMANAGER_URL}" ]] ; then
    kubectl create configmap alertmanager-env \
        "--from-literal=external-url=${ALERTMANAGER_URL}" \
        --dry-run -o json | kubectl apply -f -
fi

# Deployments
kubectl apply -f "k8s/${PROJECT}/${CLUSTER}/deployments"

# Reload configurations. If the deployment configuration has changed then this
# request may fail becuase the container has already shutdown.
# TODO: there is an indeterminate delay between the time that a configmap is
# updated and it becomes available to the container. So, this reload may fail
# since the configmap is not yet up to date.
curl -X POST http://status-${PROJECT}.measurementlab.net:9090/-/reload || :
