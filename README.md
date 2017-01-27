# prometheus-support

Prometheus configuration for M-Lab.

# Deploying Prometheus with Kubernetes

The following instructions presume there is already a kubernetes cluster
configured and accessible with `kubectl`.

See the [container engine quickstart guide][quickstart] for a simple howto.

[quickstart]: https://cloud.google.com/container-engine/docs/quickstart

## Build

To build the demo prometheus docker image:

    sudo docker login
    sudo docker build -t demo-prometheus .
    sudo docker tag demo-prometheus <username>/demo-prometheus:latest
    sudo docker push <username>/demo-prometheus:latest

## Run

To deploy the published docker image:

    kubectl run demo-prometheus --image=<username>/demo-prometheus --port=9090
    kubectl expose deployment demo-prometheus --type="LoadBalancer"
    kubectl annotate services demo-prometheus prometheus.io/scrape=true
    sleep 60 && kubectl get service demo-prometheus

After a minute or two, `kubectl get service demo-prometheus` shold report the
public IP address assigned to the prometheus service.

http://[public-IP]:9090

## Shutdown

To shutdown the service in the cluster:

    kubectl delete deployment demo-prometheus
    kubectl delete service demo-prometheus

## Add a legacy configuration

Using the file service discovery configuration, we can add new targets at
runtime. Create a JSON or YAML input file in the [correct form][file_sd_config].

Then copy the file into the prometheus container under the
`/etc/prometheus/legacy` directory.

    podname=$( kubectl get pods -o name --selector='run=demo-prometheus' )
    kubectl cp <filename.json> ${podname}:/etc/prometheus/legacy/

Within five minutes, the new targets should be reported in: Status -> Targets
-> "legacy-targets"

[file_sd_config]: https://prometheus.io/docs/operating/configuration/#file_sd_config
