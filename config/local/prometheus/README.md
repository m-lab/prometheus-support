# Local Testing

## Start Prometheus with docker

The following mounts the local directory as the Prometheus docker image config
directory. So, any local files will be visible to the docker image.

```
cd $HOME/src/github.com/m-lab/prometheus-support/config/local/prometheus
docker run -it -p 9090:9090 -v `pwd`:/etc/prometheus prom/prometheus:v1.6.2 \
    -config.file=/etc/prometheus/prometheus.yml \
    -query.staleness-delta=10s
```

Then visit: http://localhost:9090/
