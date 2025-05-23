set -e
set -u
set -x

USAGE="PROJECT=<projectid> CLUSTER=<cluster> $0"
PROJECT=${PROJECT:?Please provide project id: $USAGE}
CLUSTER=${CLUSTER:?Please provide cluster name: $USAGE}
AUTOJOIN_PROJECT=$PROJECT

# The production Autojoin GCP project is different from the usual mlab-oti
# production project.
if [[ $PROJECT == "mlab-oti" ]]; then
  AUTOJOIN_PROJECT="mlab-autojoin"
fi

K8S_INGRESS_NGINX_VERSION="4.2.1"

export GRAFANA_DOMAIN=grafana.${PROJECT}.measurementlab.net

# Construct the per-project CLIENT_ID, CLIENT_SECRET and COOKIE_SECRET for OAuth.
export OAUTH_PROXY_CLIENT_ID=OAUTH_PROXY_CLIENT_ID_${PROJECT/-/_}
export OAUTH_PROXY_CLIENT_SECRET=OAUTH_PROXY_CLIENT_SECRET_${PROJECT/-/_}
export OAUTH_PROXY_COOKIE_SECRET=OAUTH_PROXY_COOKIE_SECRET_${PROJECT/-/_}

# Generate the basic auth string for Prometheus.
export PROM_AUTH_USER=PROMETHEUS_BASIC_AUTH_USER_${PROJECT/-/_}
export PROM_AUTH_PASS=PROMETHEUS_BASIC_AUTH_PASS_${PROJECT/-/_}
export PLATFORM_PROM_AUTH_USER=PLATFORM_PROMETHEUS_BASIC_AUTH_USER
export PLATFORM_PROM_AUTH_PASS=PLATFORM_PROMETHEUS_BASIC_AUTH_PASS
export AUTH="${!PROM_AUTH_USER}:${!PROM_AUTH_PASS}"
