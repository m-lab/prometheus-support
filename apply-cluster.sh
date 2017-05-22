#!/bin/bash
#
# apply-cluster.sh applies the k8s cluster configuration to the currently
# configured cluster. This script may be safely run multiple times to load the
# most recent configurations.
#
# Example:
#
#   ./apply-cluster.sh

set -x
set -e
set -u

# Deployent dependencies.
kubectl apply -f k8s/storage-class.yml
kubectl apply -f k8s/persistent-volumes.yml

# Prometheus config map.
kubectl create configmap prometheus-cluster-config \
    --from-file=config/cluster/prometheus \
    --dry-run -o json | kubectl apply -f -

# Deployments.
kubectl apply -f k8s/cluster/prometheus.yml
kubectl apply -f k8s/node-exporter-daemonset.yml
