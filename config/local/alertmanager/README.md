# Local Testing

```
docker run -it -p 9093:9093 -v $PWD:/config prom/alertmanager:v0.15.2 \
    --config.file /config/basic.yml \
    --web.external-url=http://localhost:9093
```
