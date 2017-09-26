# Local Testing

## Start blackbox exporter with docker

The following mounts the local directory as the docker image config directory.
So, any local files will be visible to the docker image.

```
cd $HOME/src/github.com/m-lab/prometheus-support/config/local/blackbox
docker run -it -p 9115:9115 -v `pwd`:/etc/blackbox prom/blackbox-exporter:v0.4.0 \
    -config.file=/etc/blackbox/config.yml
```


Then visit: http://localhost:9115

    http://localhost:9115/probe?target=<targetname>&module=<modulename-from-config>
