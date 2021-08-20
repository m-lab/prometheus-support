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

export GRAFANA_DOMAIN=grafana.${PROJECT}.measurementlab.net

# Version numbers for Helm and Helm charts.
K8S_HELM_VERSION="v3.3.0"
K8S_INGRESS_NGINX_VERSION="2.11.2"

# GCP doesn't support IPv6, so we have a Linode VM running three instances of
# the blackbox_exporter, on three separate ports... one port/instance for each
# project. These variables map projects to ports.
BBE_IPV6_PORT_mlab_oti="9115"
BBE_IPV6_PORT_mlab_staging="8115"
BBE_IPV6_PORT_mlab_sandbox="7115"

# Construct the per-project blackbox_exporter port using the passed $PROJECT
# argument.
bbe_port=BBE_IPV6_PORT_${PROJECT/-/_}

# Construct the per-project HTTP basic auth credentials for the Reboot API.
export REBOOTAPI_BASIC_AUTH_USER=REBOOTAPI_BASIC_AUTH_${PROJECT/-/_}
export REBOOTAPI_BASIC_AUTH_PASS=REBOOTAPI_BASIC_AUTH_PASS_${PROJECT/-/_}

# Construct the per-project CLIENT_ID, CLIENT_SECRET and COOKIE_SECRET for OAuth.
export OAUTH_PROXY_CLIENT_ID=OAUTH_PROXY_CLIENT_ID_${PROJECT/-/_}
export OAUTH_PROXY_CLIENT_SECRET=OAUTH_PROXY_CLIENT_SECRET_${PROJECT/-/_}
export OAUTH_PROXY_COOKIE_SECRET=OAUTH_PROXY_COOKIE_SECRET_${PROJECT/-/_}

# Config maps and Secrets

## Credentials for accessing Stackdriver monitoring for mlab-ns.
### Write key to a file to prevent printing key in travis logs.
( set +x; echo "${SERVICE_ACCOUNT_mlab_ns}" > /tmp/mlabns.json )
kubectl create secret generic mlabns-credentials \
    "--from-file=/tmp/mlabns.json" \
    --dry-run -o json | kubectl apply -f -

## Prometheus

# Generate the basic auth string for Prometheus.
export PROM_AUTH_USER=PROMETHEUS_BASIC_AUTH_USER_${PROJECT/-/_}
export PROM_AUTH_PASS=PROMETHEUS_BASIC_AUTH_PASS_${PROJECT/-/_}
export PLATFORM_PROM_AUTH_USER=PLATFORM_PROMETHEUS_BASIC_AUTH_USER
export PLATFORM_PROM_AUTH_PASS=PLATFORM_PROMETHEUS_BASIC_AUTH_PASS
export AUTH="${!PROM_AUTH_USER}:${!PROM_AUTH_PASS}"

# Evaluate the Prometheus configuration template.
sed -e 's|{{PROJECT}}|'${PROJECT}'|g' \
    -e 's|{{BBE_IPV6_PORT}}|'${!bbe_port}'|g' \
    -e 's|{{REBOOTAPI_BASIC_AUTH}}|'${!REBOOTAPI_BASIC_AUTH_USER}'|g' \
    -e 's|{{REBOOTAPI_BASIC_AUTH_PASS}}|'${!REBOOTAPI_BASIC_AUTH_PASS}'|g' \
    -e 's|{{PLATFORM_PROM_AUTH_USER}}|'${!PLATFORM_PROM_AUTH_USER}'|g' \
    -e 's|{{PLATFORM_PROM_AUTH_PASS}}|'${!PLATFORM_PROM_AUTH_PASS}'|g' \
    config/federation/prometheus/prometheus.yml.template > \
    config/federation/prometheus/prometheus.yml

# Apply the above configmap for Prometheus.
kubectl create configmap prometheus-federation-config \
    --from-literal=gcloud-project=${PROJECT} \
    --from-file=config/federation/prometheus \
    --dry-run -o json | kubectl replace -f -

# Evaluate the Prometheus blackbox_exporter configuration template.
sed -e 's|{{PROM_AUTH_USER}}|'${!PROM_AUTH_USER}'|g' \
    -e 's|{{PROM_AUTH_PASS}}|'${!PROM_AUTH_PASS}'|g' \
    config/federation/blackbox/config.yml.template > \
    config/federation/blackbox/config.yml

## Apply the above configmap for Blackbox exporter.
kubectl create configmap blackbox-config \
    --from-file=config/federation/blackbox \
    --dry-run -o json | kubectl replace -f -

## Grafana.
kubectl create configmap grafana-config \
    --from-file=config/federation/grafana \
    --dry-run -o json | kubectl apply -f -

# Evaluate the Grafana datasource provisioning templates.
ds_tmpls=$(find config/federation/grafana/provisioning/datasources -type f)
for ds_tmpl in $ds_tmpls; do
  case "$PROJECT" in
    # Don't include sandbox or staging data sources in the production instance.
    mlab-oti)
      if [[ $(basename $ds_tmpl) != *mlab-oti* ]]; then
        rm $ds_tmpl
        continue
      fi
      ;;
    # Don't include sandbox data sources in the staging instance.
    mlab-staging)
      if [[ $(basename $ds_tmpl) == *mlab-sandbox* ]]; then
        rm $ds_tmpl
        continue
      fi
      ;;
  esac
  if [[ $ds_tmpl != *.template ]] ; then
    # Leave file as-is.
    continue
  fi
  ds_file=${ds_tmpl%%.template}
  sed -e 's|{{PROM_AUTH_USER}}|'${!PROM_AUTH_USER}'|g' \
      -e 's|{{PROM_AUTH_PASS}}|'${!PROM_AUTH_PASS}'|g' \
      -e 's|{{PLATFORM_PROM_AUTH_USER}}|'${!PLATFORM_PROM_AUTH_USER}'|g' \
      -e 's|{{PLATFORM_PROM_AUTH_PASS}}|'${!PLATFORM_PROM_AUTH_PASS}'|g' \
      $ds_tmpl > $ds_file
  if [[ $(basename $ds_file) == prometheus-federation_${PROJECT}* ]]; then
    sed -i 's|{{IS_DEFAULT}}|true|g' $ds_file
  else
    sed -i 's|{{IS_DEFAULT}}|false|g' $ds_file
  fi
  rm $ds_tmpl
done

## Grafana "provisioning" configs
kubectl create configmap grafana-datasource-provisioning \
    --from-file=config/federation/grafana/provisioning/datasources \
    --dry-run -o json | kubectl apply -f -

# Keep the password a secret.
set +x
# It does not really matter what the admin password is.
export GRAFANA_PASSWORD=$( echo $RANDOM | md5sum | awk '{print $1}' )
kubectl create secret generic grafana-secrets \
    "--from-literal=admin-password=${GRAFANA_PASSWORD}" \
    --dry-run -o json | kubectl apply -f -

kubectl create secret generic prometheus-auth \
    "--from-literal=auth=$(htpasswd -nb ${!PROM_AUTH_USER} ${!PROM_AUTH_PASS})"\
    --dry-run -o json | kubectl apply -f -

export ALERTMANAGER_URL=https://$AUTH@alertmanager.${PROJECT}.measurementlab.net

# Pass appropriate URLs to configmap-reload
export PROM_RELOAD_URL=https://$AUTH@prometheus.${PROJECT}.measurementlab.net/-/reload

kubectl create configmap configmap-reload-urls \
    "--from-literal=prometheus_reload_url=${PROM_RELOAD_URL}" \
    "--from-literal=alertmanager_reload_url=${ALERTMANAGER_URL}/-/reload" \
    --dry-run -o json | kubectl apply -f -
set -x


# Per-project client secrets and client ids should be stored in travis
# environment variables. If they are not set, then login won't work.
GF_CLIENT_SECRET_NAME=GF_AUTH_GOOGLE_CLIENT_SECRET_${PROJECT/-/_}
GF_CLIENT_ID_NAME=GF_AUTH_GOOGLE_CLIENT_ID_${PROJECT/-/_}
# TODO: kubectl v1.7  supports --from-env-file=
kubectl create configmap grafana-env \
    "--from-literal=root_url=https://${GRAFANA_DOMAIN}" \
    "--from-literal=gf_auth_google_client_secret=${!GF_CLIENT_SECRET_NAME}" \
    "--from-literal=gf_auth_google_client_id=${!GF_CLIENT_ID_NAME}" \
    --dry-run -o json | kubectl apply -f -

# Script exporter.
kubectl create configmap script-exporter-config \
  --from-file=config/federation/script-exporter/script_exporter.yml \
  --dry-run -o json | kubectl apply -f -

( set +x; echo "${MONITORING_SIGNER_KEY}" | base64 -d \
    > /tmp/monitoring-signer-key.json )
kubectl create secret generic script-exporter-secret \
  "--from-file=/tmp/monitoring-signer-key.json" \
  --dry-run -o json | kubectl apply -f -


## Alertmanager

# Evaluate the configuration template.
# Note: Slack configuration depends on travis environment variables.
# Note: Only enable the github reciever for the production project: mlab-oti.
SLACK_CHANNEL_URL_NAME=AM_SLACK_CHANNEL_URL_${PROJECT/-/_}
GITHUB_RECEIVER_URL=
GITHUB_ISSUE_QUERY=
SHORT_PROJECT=${PROJECT/mlab-/}

if [[ ${PROJECT} = "mlab-oti" ]] ; then
  # Only create one instance of the github-receiver across all projects.
  AUTH_TOKEN=${GITHUB_RECEIVER_AUTH_TOKEN}

  # For production, annotate slack messages with a link to view open alert issues.
  GITHUB_ISSUE_QUERY="https://github.com/issues?q=is%3Aissue+user%3Am-lab+author%3Ameasurementlab+is%3Aopen"
else
  # For other projects, use a fake auth token string.
  AUTH_TOKEN=fake-auth-token
fi
kubectl create secret generic github-secrets \
    "--from-literal=auth-token=${AUTH_TOKEN}" \
    --dry-run -o json | kubectl apply -f -

# Note: without a url, alertmanager will fail to start. But, for non-production
# projects, there will be no github receiver running. This should be a no-op.
GITHUB_RECEIVER_URL=http://github-receiver-service.default.svc.cluster.local:9393/v1/receiver

sed -e 's|{{SLACK_CHANNEL_URL}}|'${!SLACK_CHANNEL_URL_NAME}'|g' \
    -e 's|{{GITHUB_RECEIVER_URL}}|'$GITHUB_RECEIVER_URL'|g' \
    -e 's|{{SHORT_PROJECT}}|'$SHORT_PROJECT'|g' \
    -e 's|{{GITHUB_ISSUE_QUERY}}|'$GITHUB_ISSUE_QUERY'|g' \
    -e 's|{{PAGERDUTY_SERVICE_KEY}}|'$PAGERDUTY_SERVICE_KEY'|g' \
    config/federation/alertmanager/config.yml.template > \
    config/federation/alertmanager/config.yml

# Apply the above configmap.
kubectl create configmap alertmanager-config \
    --from-file=config/federation/alertmanager \
    --dry-run -o json | kubectl apply -f -


if [[ -n "${ALERTMANAGER_URL}" ]] ; then
    kubectl create configmap alertmanager-env \
        "--from-literal=external-url=${ALERTMANAGER_URL}" \
        --dry-run -o json | kubectl apply -f -
fi

# Evaluate bq queries as templates.
for filename in config/federation/bigquery/*.template ; do
  sed -e 's|{{PROJECT}}|'${PROJECT}'|g' \
      $filename > ${filename%%.template}
done
# Apply the bigquery exporter configurations.
kubectl create configmap bigquery-exporter-config \
    --from-file=config/federation/bigquery \
    --dry-run -o json | kubectl apply -f -

# TODO: remove this in favor of a unified object model for sites & services.
# Copy manual prometheus configuration to prometheus-cluster.
# Note: we do this before applying k8s configs to guarantee that the
# prometheus-pod is running. There is some risk that the configs later may fail.
pod=$( kubectl get pods | grep prometheus-server | awk '{print $1}' )
if [[ -z "${pod}" ]] ; then
  echo "ERROR: failed to identify prometheus-server pod from cluster" >&2
  exit 1
fi

## Reboot API

# Create credentials as Kubernetes secrets.
### Write keys to a file to prevent printing key in travis logs.
( set +x; echo "${REBOOTAPI_COREOS_SSH_KEY}" | base64 -d \
  > /tmp/reboot-api-ssh.key )

kubectl create secret generic reboot-api-credentials\
    "--from-file=/tmp/reboot-api-ssh.key" \
    --dry-run -o json | kubectl apply -f -

# Replace variables in reboot-api.yml.
sed -i -e 's|{{REBOOTAPI_USER}}|'${!REBOOTAPI_BASIC_AUTH_USER}'|g' \
    -e 's|{{REBOOTAPI_PASS}}|'${!REBOOTAPI_BASIC_AUTH_PASS}'|g' \
    k8s/prometheus-federation/deployments/reboot-api.yml

## Rebot
# Replace variables in rebot.yml.
sed -i -e 's|{{REBOOTAPI_USER}}|'${!REBOOTAPI_BASIC_AUTH_USER}'|g' \
    -e 's|{{REBOOTAPI_PASS}}|'${!REBOOTAPI_BASIC_AUTH_PASS}'|g' \
    -e 's|{{PROM_AUTH_USER}}|'${!PROM_AUTH_USER}'|g' \
    -e 's|{{PROM_AUTH_PASS}}|'${!PROM_AUTH_PASS}'|g' \
    k8s/prometheus-federation/deployments/rebot.yml

# Check for per-project template variables.
if [[ ! -f "k8s/${CLUSTER}/${PROJECT}.yml" ]] ; then
  echo "No template variables found for k8s/${CLUSTER}/${PROJECT}.yml"
  # This is not necessarily an error, so exit cleanly.
  exit 0
fi

## Switch Monitoring

# Create credentials as Kubernetes secrets.
### Write keys to a file to prevent printing key in travis logs.
( set +x; echo "${SWITCH_MONITORING_SSH_KEY}" | base64 -d \
  > /tmp/switch-monitoring.key )

kubectl create secret generic switch-monitoring-credentials\
  "--from-file=/tmp/switch-monitoring.key" \
  --dry-run -o json | kubectl apply -f -

## OAuth2 Proxy

# Replace template variables in oauth2-proxy.yml.
sed -i -e 's|{{OAUTH_PROXY_CLIENT_ID}}|'${!OAUTH_PROXY_CLIENT_ID}'|g' \
    -e 's|{{OAUTH_PROXY_CLIENT_SECRET}}|'${!OAUTH_PROXY_CLIENT_SECRET}'|g' \
    -e 's|{{OAUTH_PROXY_COOKIE_SECRET}}|'${!OAUTH_PROXY_COOKIE_SECRET}'|g' \
    k8s/prometheus-federation/deployments/oauth2-proxy.yml

# Apply templates
CFG=/tmp/${CLUSTER}-${PROJECT}.yml
kexpand expand --ignore-missing-keys k8s/${CLUSTER}/*/*.yml \
    -f k8s/${CLUSTER}/${PROJECT}.yml > ${CFG}
kubectl apply -f ${CFG} || (cat ${CFG} && exit 1)

# Reload configurations. If the deployment configuration has changed then this
# request may fail becuase the container has already shutdown.
# TODO: there is an indeterminate delay between the time that a configmap is
# updated and it becomes available to the container. So, this reload may fail
# since the configmap is not yet up to date.
# curl -X POST https://prometheus.${PROJECT}.measurementlab.net/-/reload || :

#
# Additional k8s resources installed via Helm
#
# Download Helm
curl -O https://get.helm.sh/helm-${K8S_HELM_VERSION}-linux-amd64.tar.gz
tar -zxvf helm-${K8S_HELM_VERSION}-linux-amd64.tar.gz

# Install the NGINX ingress controller in the ingress-nginx namespace.
kubectl create namespace ingress-nginx --dry-run -o json | kubectl apply -f -
./linux-amd64/helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
./linux-amd64/helm repo update
./linux-amd64/helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --version ${K8S_INGRESS_NGINX_VERSION} \
  --values helm/prometheus-federation/ingress-nginx/${PROJECT}.yml
