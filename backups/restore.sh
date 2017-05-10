#!/bin/bash
#
# restore.sh uses GRAFANA_HOST and GRAFANA_API_KEY variables from the
# environment to restore dashboards and datasources found in the $PWD.

set -xue

# Note: assert that the variables are defined.
DIR=${1:?Error: provide a directory for reading backups: $0 <dir>}
_=${GOPATH:?Error: set GOPATH in environment before execution.}
_=${GRAFANA_HOST:?Error: set GRAFANA_HOST in environment before execution.}
_=${GRAFANA_API_KEY:?Error: set GRAFANA_API_KEY in environment before execution.}

go get github.com/grafana-tools/sdk/cmd/import-dashboards
go get github.com/grafana-tools/sdk/cmd/import-datasources

# Note: we must import datasources first, otherwise the references in the
# dashboards cannot be resolved and the dashboards will not work.
pushd "$DIR"
  pushd datasources
    ~/bin/import-datasources "${GRAFANA_HOST}" "${GRAFANA_API_KEY}"
  popd

  pushd dashboards
    ~/bin/import-dashboards "${GRAFANA_HOST}" "${GRAFANA_API_KEY}"
  popd
popd
