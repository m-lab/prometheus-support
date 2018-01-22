Grafana JSON dashboard will be stored in this directory to implement
dashboards-as code.

**NOTE**: With the current version of Grafana (4.6.3), you cannot use unmodified
JSON from the export feature of Grafana, as this JSON is intented to be consumed
directly by the import feature. You have three options:
* Download the JSON using the export feature, and then manually change all
  instances of `${DS_PROMETHEUS}` to `Prometheus`.
* View the JSON in the Grafana interface, then cut-and-paste it into a file.
* Use some 3rd party Grafana API client (e.g. grafcli) to download the JSON.
