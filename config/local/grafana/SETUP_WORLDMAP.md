## Setup the Grafana WorldMap Plugin


Rough notes:

* manually install the worldmap plugin in Grafana server `/var/lib/grafana/plugins`.
* create a GCS bucket for the json location data.
* set defactl on bucket:
  ```
  $ gsutil defacl set public-read gs://prometheus-support-mlab-sandbox/
  ```
* set cors policy on bucket, so requests evaluate `Access-Control-Allow-Origin`
  headers correctly.
  ```
  $ gsutil cors set cors.json  gs://prometheus-support-mlab-sandbox
  ```

  `cors.json` contains, a project-specific origin:
  ```
  [
    {
      "origin": ["http://localhost:3000", "https://grafana.mlab-sandbox.measurementlab.net"],
      "responseHeader": ["Content-Type"],
      "method": ["GET", "HEAD", "DELETE"],
      "maxAgeSeconds": 3600
    }
  ]
  ```

* The worldmap plugin uses the "Legend" field to identify the label to use and
  look for in the location list.
