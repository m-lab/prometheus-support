#!/bin/bash

set -e
set -x
set -u

CACHE_CONTROL="Cache-Control:private, max-age=0, no-transform"

USAGE="Usage: $0 <project>"
PROJECT=${1:?Please provide project name: $USAGE}

# Root directory of this script.
BASEDIR=${PWD}

# Generate the configs.
${BASEDIR}/generate_prometheus_targets.sh > /dev/null

# Be sure that gcloud is PATH
source "${HOME}/google-cloud-sdk/path.bash.inc"

# Authenticate all operations using the given service account.
if [[ -f /tmp/${PROJECT}.json ]] ; then
  gcloud auth activate-service-account --key-file /tmp/${PROJECT}.json
else
  echo "Service account key not found at /tmp/${PROJECT}.json!!"
  echo "Using default credentials."
fi

# Copy the configs to GCS.
gsutil -h "$CACHE_CONTROL" cp -r \
  ${BASEDIR}/gen/${PROJECT}/prometheus \
  gs://operator-${PROJECT}
