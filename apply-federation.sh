#!/bin/bash
#
# apply-federation.sh applies the k8s federation configuration to the currently
# configured cluster. This script may be safely run multiple times to load the
# most recent configurations.
#
# If a config file (config/*) changes, the pod does not automatically restart
# when the configmap for that config file is updated. You must manually delete
# the pod, and kubernetes will recreate it with the new config.
#
# Example:
#
# GRAFANA_DOMAIN=status-mlab-staging.measurementlab.net \
#   GRAFANA_PASSWORD=<password> \
#   ALERTMANAGER_URL=http://status-mlab-staging.measurementlab.net:9093 \
#   ./apply-federation.sh mlab-staging

set -x
set -e
set -u

USAGE="$0 <projectid> [<grafana passwd>]"
PROJECT=${1:?Please provide project id: $USAGE}

# Deployent dependencies.
kubectl apply -f k8s/storage-class.yml
kubectl apply -f k8s/persistent-volumes.yml

# Services.
kubectl apply -f k8s/${PROJECT}/prometheus-federation

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

if [[ -n "$GRAFANA_PASSWORD" ]] ; then
  kubectl create secret generic grafana-secrets \
      "--from-literal=admin-password=${GRAFANA_PASSWORD}" \
      --dry-run -o json | kubectl apply -f -
fi
if [[ -n "${GRAFANA_DOMAIN}" ]] ; then
  kubectl create configmap grafana-env \
      "--from-literal=domain=${GRAFANA_DOMAIN}" \
      --dry-run -o json | kubectl apply -f -
fi

## Alertmanager
kubectl create configmap alertmanager-config \
    --from-file=config/federation/alertmanager \
    --dry-run -o json | kubectl apply -f -

if [[ -n "${ALERTMANAGER_URL}" ]] ; then
    kubectl create configmap alertmanager-env \
        "--from-literal=external-url=${ALERTMANAGER_URL}" \
        --dry-run -o json | kubectl apply -f -
fi

# Deployments
kubectl apply -f k8s/node-exporter-daemonset.yml
kubectl apply -f k8s/federation/blackbox.yml
kubectl apply -f k8s/federation/grafana.yml
kubectl apply -f k8s/federation/prometheus.yml
kubectl apply -f k8s/federation/alertmanager.yml
