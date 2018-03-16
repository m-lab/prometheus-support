#!/bin/bash

set -e
set -u
set -x

USAGE="Usage: $0 <project> <keyname>"
PROJECT=${1:?Please provide project name: $USAGE}
KEYNAME=${2:?Please provide an authentication key name: $USAGE}
BBE_CONFIG="config/federation/blackbox/config.yml"
LINODE_DOMAIN="blackbox-exporter-ipv6.${PROJECT}.measurementlab.net"
LINODE_USER="mlab"
LOCAL_KEY_FILE="id_rsa_linode"
SSH_OPTS="-i $LOCAL_KEY_FILE -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"

# Extract the SSH key from the configured Travis environment variable. The key
# is base64 encoded to avoid the need for shell escaping and newlines. Set the
# mode of the file appropriately, as SSH will refuse to use it if the
# permissions are not strict enough.
echo "${!KEYNAME}" | base64 -d > $LOCAL_KEY_FILE
chmod 600 $LOCAL_KEY_FILE

# Copy blackbox_exporter config file to the Linode VM.
scp $SSH_OPTS $BBE_CONFIG $LINODE_USER@$LINODE_DOMAIN:blackbox-exporter-config-$PROJECT.yml

# HUP the blackbox_exporter so it reads the new config.
ssh $SSH_OPTS $LINODE_USER@$LINODE_DOMAIN "docker exec ${PROJECT} kill -HUP 1"
