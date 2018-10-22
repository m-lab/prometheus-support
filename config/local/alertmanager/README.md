## Local Alertmanager Testing


If you wish for the local prometheus config to reference localhost for the
alertmanager, OR if you are developing a local webhook receiver, also use
`--net=host`.

For local alertmanager testing, start the container:
```
docker run -it -p 9093:9093 \
    -v $PWD:/config prom/alertmanager:v0.15.2 \
    --config.file /config/local.yml \
    --web.external-url=http://localhost:9093
```
