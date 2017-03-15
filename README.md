# prometheus-support

Prometheus configuration for M-Lab.

# Building an M-Lab Prometheus image

To build the demo prometheus docker image:

Log into your personal docker account, to publish the newly built image.

    DOCKERUSER=$USER   # Use your actual dockerhub username.
    sudo docker login
    sudo docker build -t prometheus-server .
    sudo docker tag prometheus-server $DOCKERUSER/prometheus-server:latest
    sudo docker push $DOCKERUSER/prometheus-server:latest

# Deploying Prometheus to Kubernetes

The following instructions presume there is already a kubernetes cluster
configured and accessible with `kubectl`.

See the [container engine quickstart guide][quickstart] for a simple howto.

[quickstart]: https://cloud.google.com/container-engine/docs/quickstart

## Testing: Using explicit kubectl commands

This option is helpful for testing. There is no persistent storage.

### Start

The `kubectl run` and `kubectl expose` commands automatically create the
services, deployments, and pods.

    kubectl run prometheus-server --image=$DOCKERUSER/prometheus-server --port=9090
    kubectl expose deployment prometheus-server --type="LoadBalancer"
    kubectl annotate services prometheus-server prometheus.io/scrape=true
    sleep 60 && kubectl get service prometheus-server

After a minute or two, `kubectl get service prometheus-server` should report the
public IP address assigned to the prometheus service.

For example: [http://127.0.0.1:9090](http://127.0.0.1:9090) (but you should use
the actual public IP address).

### Shutdown

To shutdown the service in the cluster:

    kubectl delete deployment prometheus-server
    kubectl delete service prometheus-server

Since there is no persistent storage, all data collected will be lost.

### Add configuration for legacy targets

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
`/legacy-targets` directory.

    podname=$( kubectl get pods -o name --selector='run=prometheus-server' )
    kubectl cp <filename.json> ${podname##*/}:/legacy-targets/

Within five minutes, the new targets should be reported in: Status -> Targets
-> "legacy-targets"

[file_sd_config]: https://prometheus.io/docs/operating/configuration/#file_sd_config


## Automation: Using predefined Kubernetes config files

Kubernetes config files preserve a deployment configuration and provide a
convenient mechanism for review and automated deployments.

Some steps cannot be automated. For example, while a LoadBalancer can
automatically assign a public IP address to a service, it will not ([yet](dns)
update corresponding DNS records for that IP address. So, we must reserve a
static IP through the Cloud Console interface first.

*Also, note*: Only one GKE cluster at a time can use the static IPs allocated in
the `k8s/.../services.yml` files. If you are using an additional GKE cluster (e.g.
in mlab-sandbox project), create a new services.yml file that uses the new
static IP allocation.

[dns]: https://github.com/kubernetes-incubator/external-dns

## ConfigMaps

Create the ConfigMap for prometheus:

    kubectl create configmap prometheus-config --from-file=prometheus

While the flag is `--from-file` it accepts a directory, and creates a
ConfigMap with keys equal to the filenames and values equal to the content of
the file.

    kubectl describe configmap prometheus-config

      Name:       prometheus-config
      Namespace:  default
      Labels:     <none>
      Annotations:    <none>

      Data
      ====
      prometheus.yml: 9754 bytes

We can now refer to this ConfigMap in the deployment configs below. For
example, k8s/prometheus.yml maps the prometheus configuration as a volume so
that the file `prometheus.yml` appears under `/etc/prometheus`.

    - containers:
      ...
        volumeMounts:
          # /etc/prometheus/prometheus.yml should contain the M-Lab Prometheus config.
          - mountPath: /etc/prometheus
            name: prometheus-config
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config

Note: Configmaps only support text data. Secrets may be an alternative for
binary data. https://github.com/kubernetes/kubernetes/issues/32432

### Update a ConfigMap

When the content of a configmap value needs to change, you can either delete and
create the configmap object (not ideal), or replace the new configuration all at
once.

    kubectl create configmap prometheus-config --from-file=prometheus \
        --dry-run -o json | kubectl apply -f -

## Start

Before beginning, verify that you are [operating on the correct kubernetes
cluster][cluster].

Then, update k8s/prometheus.yml to reference the latest container version.

Then, deploy the service:

Creates a storage class for GCE persistent disks.

    kubectl create -f k8s/storage-class.yml

Creates a persistent volume claim that Prometheus will bind to.

    kubectl create -f k8s/persistent-volumes.yml

Creates a service using the public IP address that will send traffic to pods
with the label "run=prometheus-server".

    kubectl create -f k8s/mlab-sandbox/services.yml

Creates the prometheus deployment. This receives traffic from the service above
and binds to the persistent volume claim. If a persistent volume does not
already exist, this will create a new one. It will be automatically formatted.

    kubectl create -f k8s/prometheus.yml

[cluster]: https://cloud.google.com/container-engine/docs/clusters/operations

## Shutdown

Delete the prometheus deployment.

    kubectl delete -f k8s/prometheus.yml

Since the prometheus pod is no longer running, clients connecting to the public
IP address will try to load and timeout. If we also delete the service, then
traffic will stop being forwarded form the public IP.

    kubectl delete -f k8s/mlab-sandbox/services.yml

Even if the prometheus deployment is not running, the persistent volume keeps
the data around. If the cluster is destroyed or if the persistent volume claim
is deleted, the automatically created disk image will be garbage collected and
deleted. At that point all data will be lost.

    kubectl delete -f k8s/persistent-volumes.yml

Delete the storage class.

    kubectl delete -f k8s/storage-class.yml


# Debugging the steps above

## Public IP appears to hang

After `kubectl get service prometheus-server` assigns a public IP, you can visit
the service at that IP, e.g. http://[public-ip]:9090. If the service appears to
hang, the docker instance may have failed to start.

Check using:

```
$ kubectl get pods
NAME                               READY     STATUS             RESTARTS   AGE
prometheus-server-2562116152-9mdrq   0/1       CrashLoopBackOff   9          25m
```

In this case, the `READY` status is "0", meaning not yet ready. And, the
`STATUS` gives a clue that the docker instance is crashing immediately after
start.

## Viewing logs

If a docker instance is misbehaving, we can view the logs reported by that
instance using `kubectl logs`. For example, in the case above, we can ask for
the logs with the pod name.

```
$ kubectl logs prometheus-server-2562116152-9mdrq
time="2017-02-01T21:02:36Z" level=info msg="Starting prometheus (version=1.5.0, branch=master, revision=d840f2c400629a846b210cf58d65b9fbae0f1d5c)" source="main.go:75"
time="2017-02-01T21:02:36Z" level=info msg="Build context (go=go1.7.4, user=root@a04ed5b536e3, date=20170123-13:56:24)" source="main.go:76"
time="2017-02-01T21:02:36Z" level=info msg="Loading configuration file /etc/prometheus/prometheus.yml" source="main.go:248"
time="2017-02-01T21:02:36Z" level=error msg="Error loading config: couldn't load configuration (-config.file=/etc/prometheus/prometheus.yml): yaml: line 2: mapping values are not allowed in this context" source="main.go:150"
```
