#!/bin/bash
#
# backup.sh uses GRAFANA_HOST and GRAFANA_API_KEY variables from the environment
# to backup all known dashboards and datasources.

set -xue

# Note: assert that the variables are defined.
DIR=${1:?Error: provide a directory for saving backups: $0 <dir>}
_=${GOPATH:?Error: set GOPATH in environment before execution.}
_=${GRAFANA_HOST:?Error: set GRAFANA_HOST in environment before execution.}
_=${GRAFANA_API_KEY:?Error: set GRAFANA_API_KEY in environment before execution.}

go get github.com/grafana-tools/sdk/cmd/backup-dashboards
go get github.com/grafana-tools/sdk/cmd/backup-datasources

mkdir -p "${DIR}"
pushd "${DIR}"
  mkdir -p datasources
  pushd datasources
    ~/bin/backup-datasources "${GRAFANA_HOST}" "${GRAFANA_API_KEY}"
  popd


  mkdir -p dashboards
  pushd dashboards
    ~/bin/backup-dashboards "${GRAFANA_HOST}" "${GRAFANA_API_KEY}"
  popd
popd
