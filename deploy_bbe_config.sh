#!/bin/bash
#
# Deploys the blackbox_exporter config to an external (e.g., Linode) VM which
# will perform IPv6 probes, since GCP doesn't currently support IPv6.
#
#  Example usage:
#    ./deploy_bbe_config.sh mlab-sandbox LINODE_PRIVATE_KEY_ipv6_monitoring

set -e
set -u
set -x

BASE_DIR=$( dirname ${BASH_SOURCE[0]} )
USAGE="Usage: $0 <project> <keyname>"
PROJECT=${1:?Please provide project name: $USAGE}
KEYNAME=${2:?Please provide an authentication key name: $USAGE}
BBE_CONFIG="${BASE_DIR}/config/federation/blackbox/config.yml"
LINODE_DOMAIN="blackbox-exporter-ipv6.${PROJECT}.measurementlab.net"
LINODE_USER="mlab"
LOCAL_KEY_FILE="id_rsa_linode"
SSH_OPTS="-i $LOCAL_KEY_FILE -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"

# Extract the SSH key from the configured Travis environment variable. The key
# is base64 encoded to avoid the need for shell escaping and newlines. Set the
# mode of the file appropriately, as SSH will refuse to use it if the
# permissions are not strict enough.
set +x
echo "${!KEYNAME}" | base64 -d > $LOCAL_KEY_FILE
set -x
chmod 600 $LOCAL_KEY_FILE

# Copy blackbox_exporter config file to the Linode VM.
scp $SSH_OPTS $BBE_CONFIG $LINODE_USER@$LINODE_DOMAIN:blackbox-exporter-config-$PROJECT.yml

# HUP the blackbox_exporter so it reads the new config.
ssh $SSH_OPTS $LINODE_USER@$LINODE_DOMAIN "docker exec ${PROJECT} kill -HUP 1"
