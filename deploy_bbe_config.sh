#!/bin/bash
#
# Deploys the blackbox_exporter config to the GCE monitoring VM which performs
# IPv6 probes for the given project.
#
#  Example usage:
#    ./deploy_bbe_config.sh mlab-sandbox

set -e
set -u
set -x

BASE_DIR=$( dirname ${BASH_SOURCE[0]} )
USAGE="Usage: $0 <project>"
PROJECT=${1:?Please provide project name: $USAGE}
BBE_CONFIG="${BASE_DIR}/config/federation/blackbox/config.yml"
VM_NAME="ipv6-monitoring"
VM_CONFIG_DIR="/etc/blackbox-exporter"
VM_CONFIG_FILE="${VM_CONFIG_DIR}/config.yml"
BBE_IMAGE="prom/blackbox-exporter:v0.20.0"
CONTAINER_NAME="blackbox-exporter"

# Map projects to zones where the monitoring VM is deployed.
ZONE_mlab_sandbox="us-central1-c"
ZONE_mlab_staging="us-east1-c"
ZONE_mlab_oti="us-central1-a"

zone_var=ZONE_${PROJECT/-/_}
ZONE="${!zone_var}"

GCE_OPTS="--tunnel-through-iap --project=${PROJECT} --zone=${ZONE}"

# Copy blackbox_exporter config to the VM.
gcloud compute scp ${GCE_OPTS} \
    "${BBE_CONFIG}" "${VM_NAME}:/tmp/blackbox-exporter-config.yml"

# Ensure config directory exists, install config, then start or reload the container.
gcloud compute ssh ${GCE_OPTS} "${VM_NAME}" --command=" \
    sudo mkdir -p ${VM_CONFIG_DIR} && \
    sudo mv /tmp/blackbox-exporter-config.yml ${VM_CONFIG_FILE} && \
    sudo chmod 644 ${VM_CONFIG_FILE} && \
    if sudo docker inspect ${CONTAINER_NAME} > /dev/null 2>&1; then \
        sudo docker kill --signal=HUP ${CONTAINER_NAME}; \
    else \
        sudo docker run --detach --network=host \
            --volume ${VM_CONFIG_DIR}:${VM_CONFIG_DIR}:ro \
            --restart always --name ${CONTAINER_NAME} ${BBE_IMAGE} \
            --config.file=${VM_CONFIG_FILE}; \
    fi \
"
