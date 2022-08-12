#!/bin/bash
#
# This script should be run _after_ the prometheus-federation cluster is already
# up and running, but before apply-global-prometheus.sh is run for the first
# time.  apply-global-prometheus.sh gets run when a Cloud Build is triggered for
# this repository. This script will apply any changes to the cluster that need
# to happen in advance.

PROJECT=${1:?Please provide a GCP project name}
ZONE=${2:?Please provide the GCP zone of the cluster}

# Get credentials for interacting with the cluster
gcloud container clusters get-credentials prometheus-federation --project $PROJECT --zone $ZONE

# Builds of this repository are done by Cloud Build. Cloud Build performs these
# builds using the default Cloud Build service account. However, the Cloud Build
# service account needs to have certain RBAC permissions in the cluster in order
# to be able to deploy the cluster and apply all necessary changes. It is not
# currently known why IAM permissions on the cluster are not sufficient, but for
# some reason they are not. This article gives _some_ background:
#
# https://cloud.google.com/kubernetes-engine/docs/how-to/role-based-access-control#permission_to_create_or_update_roles_and_role_bindings
#
# Get the project's "projectNumber" so that we can evaluate the
# ClusterRoleBinding template, and then apply that the cluster.
project_number=$(gcloud projects describe $PROJECT --format="value(projectNumber)")
sed -e 's|{{PROJECT_NUMBER}}|'$project_number'|g' \
  k8s/prometheus-federation/roles/cloud-build.yml.template > \
  k8s/prometheus-federation/roles/cloud-build.yml
kubectl apply -f k8s/prometheus-federation/roles/cloud-build.yml
