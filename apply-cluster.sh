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

USAGE="$0 <project-id> <cluster-name>"
PROJECT=${1:?Please provide project id: $USAGE}
CLUSTER=${2:?Please provide cluster name: $USAGE}

# Roles.
kubectl apply -f "k8s/${PROJECT}/${CLUSTER}/roles"

# Deployent dependencies.
kubectl apply -f "k8s/${PROJECT}/${CLUSTER}/persistentvolumes"

# Prometheus config map.
kubectl create configmap prometheus-cluster-config \
    --from-file=config/cluster/prometheus \
    --dry-run -o json | kubectl apply -f -

# Services
kubectl apply -f "k8s/${PROJECT}/${CLUSTER}/services"

# Deployments
kubectl apply -f "k8s/${PROJECT}/${CLUSTER}/deployments"

# Get the public IP for the prometheus service.
PUBLIC_IP=$( kubectl get services \
  -o jsonpath='{.items[?(@.metadata.name=="prometheus-public-service")].status.loadBalancer.ingress[0].ip}' )
if [[ -n "${PUBLIC_IP}" ]] ; then
  # Reload configurations. If the deployment configuration has changed then this
  # request may fail becuase the container has already shutdown.
  curl -X POST http://${PUBLIC_IP}:9090/-/reload || :
fi
