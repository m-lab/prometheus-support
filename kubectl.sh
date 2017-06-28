#!/bin/bash
#
# Load k8s cluster credentials for kubectl and run a given command.

set -x
set -e
set -u

USAGE="$0 <project> <cluster> <command>"
PROJECT=${1:?Please provide the project: $USAGE}
CLUSTER=${2:?Please provide the cluster: $USAGE}
shift 2

# Add gcloud to PATH.
source "${HOME}/google-cloud-sdk/path.bash.inc"

KEYFILE="/tmp/${PROJECT}.json"
if [[ ! -f "${KEYFILE}" ]] ; then
  echo "ERROR: service account key file for $PROJECT not found!"
  exit 1
fi

# All operations are performed as the service account named in KEYFILE.
# For all options see:
# https://cloud.google.com/sdk/gcloud/reference/auth/activate-service-account
gcloud auth activate-service-account --key-file "${KEYFILE}"

# For all options see:
# https://cloud.google.com/sdk/gcloud/reference/config/set
gcloud config set core/project "${PROJECT}"
gcloud config set core/disable_prompts true
gcloud config set core/verbosity debug

# Identify the cluster ZONE.
ZONE=$( gcloud container clusters list \
  --format='table[no-heading](locations[0])' \
  --filter "name='$CLUSTER'" )

if [[ -z "$ZONE" ]] ; then
  echo "ERROR: could not find zone for $CLUSTER"
  exit 1
fi

# Get credentials from the cluster.
gcloud container clusters get-credentials $CLUSTER --zone $ZONE

# Make the project and cluster available to sub-commands.
export ZONE
export PROJECT
export CLUSTER

# Run command given on the rest of the command line.
$@
