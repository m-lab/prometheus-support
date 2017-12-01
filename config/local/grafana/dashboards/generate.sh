#!/bin/bash

BASEDIR=$( dirname "${BASH_SOURCE[0]}" )
# Grafana requires world readership. Setting umask only affects the local shell.
umask 0002
for file in `ls ${BASEDIR}/*.dashboard.py` ; do
  prefix=${file%%.dashboard.py}
  echo "Generating: ${prefix}.json"
  python3 /usr/local/bin/generate-dashboard -o ${prefix}.json ${file}
done
