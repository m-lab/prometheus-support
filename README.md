# prometheus-support

Prometheus configuration for M-Lab.

# Deploying Prometheus with Kubernetes

The following instructions presume there is already a kubernetes cluster
configured and accessible with `kubectl`.

See the [container engine quickstart guide][quickstart] for a simple howto.

[quickstart]: https://cloud.google.com/container-engine/docs/quickstart

## Build

To build the demo prometheus docker image:

Log into your personal docker account, to publish the newly built image.

    DOCKERUSER=$USER  # Or, actual dockerhub username.
    sudo docker login
    sudo docker build -t demo-prometheus .
    sudo docker tag demo-prometheus $DOCKERUSER/demo-prometheus:latest
    sudo docker push $DOCKERUSER/demo-prometheus:latest

## Run

To deploy the published docker image:

    kubectl run demo-prometheus --image=$DOCKERUSER/demo-prometheus --port=9090
    kubectl expose deployment demo-prometheus --type="LoadBalancer"
    kubectl annotate services demo-prometheus prometheus.io/scrape=true
    sleep 60 && kubectl get service demo-prometheus

After a minute or two, `kubectl get service demo-prometheus` should report the
public IP address assigned to the prometheus service.

http://[public-IP]:9090

## Shutdown

To shutdown the service in the cluster:

    kubectl delete deployment demo-prometheus
    kubectl delete service demo-prometheus

## Add a legacy configuration

Using the file service discovery configuration, we can add new targets at
runtime. Create a JSON or YAML input file in the [correct form][file_sd_config].

For example:

```
[
    {
        "labels": {
            "service": "sidestream"
        },
        "targets": [
            "npad.iupui.mlab4.mia03.measurement-lab.org:9090"
        ]
    }
]
```

Then copy the file into the prometheus container under the
`/etc/prometheus/legacy` directory.

    podname=$( kubectl get pods -o name --selector='run=demo-prometheus' )
    kubectl cp <filename.json> ${podname##*/}:/etc/prometheus/legacy/

Within five minutes, the new targets should be reported in: Status -> Targets
-> "legacy-targets"

[file_sd_config]: https://prometheus.io/docs/operating/configuration/#file_sd_config

# Debugging the steps above

## Public IP appears to hang

After `kubectl get service demo-prometheus` assigns a public IP, you can visit
the service at that IP, e.g. http://[public-ip]:9090. If the service appears to
hang, the docker instance may have failed to start.

Check using:

```
$ kubectl get pods
NAME                               READY     STATUS             RESTARTS   AGE
demo-prometheus-2562116152-9mdrq   0/1       CrashLoopBackOff   9          25m
```

In this case, the `READY` status is "0", meaning not yet ready. And, the
`STATUS` gives a clue that the docker instance is crashing immediately after
start.

## Viewing logs

If a docker instance is misbehaving, we can view the logs reported by that
instance using `kubectl logs`. For example, in the case above, we can ask for
the logs with the pod name.

```
$ kubectl logs demo-prometheus-2562116152-9mdrq
time="2017-02-01T21:02:36Z" level=info msg="Starting prometheus (version=1.5.0, branch=master, revision=d840f2c400629a846b210cf58d65b9fbae0f1d5c)" source="main.go:75"
time="2017-02-01T21:02:36Z" level=info msg="Build context (go=go1.7.4, user=root@a04ed5b536e3, date=20170123-13:56:24)" source="main.go:76"
time="2017-02-01T21:02:36Z" level=info msg="Loading configuration file /etc/prometheus/prometheus.yml" source="main.go:248"
time="2017-02-01T21:02:36Z" level=error msg="Error loading config: couldn't load configuration (-config.file=/etc/prometheus/prometheus.yml): yaml: line 2: mapping values are not allowed in this context" source="main.go:150"
```
