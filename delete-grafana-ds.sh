#!/bin/bash
#
# Deletes a provisioned Grafana datasource.
#
#  Example usage:
#    ./delete-grafana-ds.sh mlab-sandbox 42 session-id api-key
#
# In order to use this script you need to:
# 1. Be logged into Grafana on a browser
# 2. Get the value of the _oauth2_proxy cookie (the session-id)
# 3. Generate a new API key in the API keys section in Grafana's settings
# 4. Get the ID of the datasource you want to remove
#

set -e
set -u
set -x

PROJECT=${1:?Usage: $0 <project> <datasource-id> <session-id> <api-key>}
DATASOURCE_ID=${2:?Usage: $0 <project> <datasource-id> <session-id> <api-key>}
SESSION_ID=${3:?Usage: $0 <project> <datasource-id> <session-id> <api-key>}
API_KEY=${4:?Usage: $0 <project> <datasource-id> <session-id> <api-key>}

# Make the datasource editable first.
curl --request PUT \
    --header "Content-Type: application/json" \
    --data "{\"id\": $DATASOURCE_ID, \"name\": \"$DATASOURCE_ID (delete me)\",
             \"type\": \"prometheus\", \"access\": \"server\",
             \"editable\": \"true\"}" \
    https://grafana.$PROJECT.measurementlab.net/api/datasources/$DATASOURCE_ID \
    --cookie "_oauth2_proxy=$SESSION_ID" \
    -H "Authorization: Bearer $API_KEY"

# Delete the Datasource.
curl --request DELETE --header "Authorization: Bearer $API_KEY" \
    https://grafana.$PROJECT.measurementlab.net/api/datasources/$DATASOURCE_ID \
    --cookie "_oauth2_proxy=$SESSION_ID"
