set -e
set -u
set -x

USAGE="PROJECT=<projectid> CLUSTER=<cluster> $0"
PROJECT=${PROJECT:?Please provide project id: $USAGE}
CLUSTER=${CLUSTER:?Please provide cluster name: $USAGE}

K8S_INGRESS_NGINX_VERSION="4.2.1"

export GRAFANA_DOMAIN=grafana.${PROJECT}.measurementlab.net

# Construct the per-project CLIENT_ID, CLIENT_SECRET and COOKIE_SECRET for OAuth.
export OAUTH_PROXY_CLIENT_ID=OAUTH_PROXY_CLIENT_ID_${PROJECT/-/_}
export OAUTH_PROXY_CLIENT_SECRET=OAUTH_PROXY_CLIENT_SECRET_${PROJECT/-/_}
export OAUTH_PROXY_COOKIE_SECRET=OAUTH_PROXY_COOKIE_SECRET_${PROJECT/-/_}