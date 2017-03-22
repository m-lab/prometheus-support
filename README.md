# prometheus-support

Prometheus configuration for M-Lab.

# Deploying Prometheus to Kubernetes

The following instructions presume there is already a kubernetes cluster
created in a GCP project and the cluster is accessible with `kubectl`.

See the [container engine quickstart guide][quickstart] for a simple howto.

[quickstart]: https://cloud.google.com/container-engine/docs/quickstart

# Using Kubernetes config files

Kubernetes config files preserve a deployment configuration and provide a
convenient mechanism for review and automated deployments.

Some steps cannot be automated. For example, while a LoadBalancer can
automatically assign a public IP address to a service, it will not ([yet](dns)
update corresponding DNS records for that IP address. So, we must reserve a
static IP through the Cloud Console interface first.

*Also, note*: Only one GKE cluster at a time can use the static IPs allocated
in the `k8s/.../services.yml` files. If you are using an additional GKE cluster
(e.g.  in mlab-sandbox project), create a new services.yml file that uses the
new static IP allocation.

[dns]: https://github.com/kubernetes-incubator/external-dns

## ConfigMaps

Many services like prometheus provide canonical docker images publised to
dockerhub (or other registry). We can customize the deployment by changing the
configuration at run time using ConfigMaps. For detailed background see the
[official docs][configmaps].

Create a ConfigMap for prometheus:

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

We can now refer to this ConfigMap in the "deployment" coniguration later. For
example, k8s/prometheus.yml declares the prometheus configuration as a volume so
that the file `prometheus.yml` appears under `/etc/prometheus`.

For example this will look something like (with abbreviated configuration):

    - containers:
      ...
        volumeMounts:
          # /etc/prometheus/prometheus.yml should contain the M-Lab Prometheus
          # config.
          - mountPath: /etc/prometheus
            name: prometheus-config
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config

Note: Configmaps only support text data. Secrets may be an alternative for
binary data. https://github.com/kubernetes/kubernetes/issues/32432

[configmaps]: https://kubernetes.io/docs/user-guide/configmap/

### Verify that a ConfigMap is Mounted

When a pod has mounted a configmap (or other resource), it is visible in the
"Volume Mounts" status reported by `kubectl describe`.

For example (with abbreviated output):

    podname=$( kubectl get pods -o name --selector='run=prometheus-server' )
    kubectl describe ${podname}
      ...
      Containers:
        prometheus-server:
          ...
          Image:              prom/prometheus:v1.5.2
          ...
          Port:               9090/TCP
          ...
          Volume Mounts:
            /etc/prometheus from prometheus-config (rw)
            /legacy-targets from prometheus-storage (rw)
            /prometheus from prometheus-storage (rw)
          ...

### Update a ConfigMap

When the content of a configmap value needs to change, you can either delete and
create the configmap object (not ideal), or replace the new configuration all at
once.

    kubectl create configmap prometheus-config --from-file=prometheus \
        --dry-run -o json | kubectl apply -f -

After updating a configmap, any pods that use this configmap will need to be
restarted for the change to take effect.

    podname=$( kubectl get pods -o name --selector='run=prometheus-server' )
    kubectl delete ${podname}

The deployment replica set will automatically recreate the pod and the new
prometheus server will use the updated configmap. This is a known issue:
https://github.com/kubernetes/kubernetes/issues/13488

## Create deployment

Before beginning, verify that you are [operating on the correct kubernetes
cluster][cluster].

Then, update k8s/prometheus.yml to reference the latest stable prometheus
container tag. Now, deploy the service.

Create a storage class for GCE persistent disks:

    kubectl create -f k8s/storage-class.yml

Create a persistent volume claim that Prometheus will bind to:

    kubectl create -f k8s/persistent-volumes.yml

Note: Persistent volume claims are intended to exist longer than pods. This
allows persistent disks to be dynamically allocated and preserved across pod
creations and deletions.

Create a service using the public IP address that will send traffic to pods
with the label "run=prometheus-server":

    kubectl create -f k8s/mlab-sandbox/services.yml

Create the prometheus deployment. This is the last step and includes the actual
prometheus server. The deployment will receive traffic from the service defined
above and binds to the persistent volume claim. If a persistent volume does not
already exist, this will create a new one. It will be automatically formatted.

    kubectl create -f k8s/prometheus.yml

After completing the above steps, you can view the status of all objects using
something like:

    kubectl get services,deployments,pods,configmaps,pvc,pv,events

`kubectl get` is your friend. See also `kubectl describe` for even more details.

[cluster]: https://cloud.google.com/container-engine/docs/clusters/operations

## Add Legacy Targets

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

Then copy the file into the prometheus container under the `/legacy-targets`
directory.

    podname=$( kubectl get pods -o name --selector='run=prometheus-server' )
    kubectl cp <filename.json> ${podname##*/}:/legacy-targets/

To look at the available files in the `legacy-targets` directory:

    kubectl exec -t ${podname##*/} -- /bin/ls -l /legacy-targets

Within five minutes, any file ending with `*.json` or `*.yaml` will be scanned
and the new targets should be reported by the prometheus server, listed under:
Status -> Targets -> "legacy-targets"

[file_sd_config]: https://prometheus.io/docs/operating/configuration/#file_sd_config

## Delete deployment

Delete the prometheus deployment.

    kubectl delete -f k8s/prometheus.yml

Since the prometheus pod is no longer running, clients connecting to the public
IP address will try to load but fail. If we also delete the service, then
traffic will stop being forwarded from the public IP altogether.

    kubectl delete -f k8s/mlab-sandbox/services.yml

Even if the prometheus deployment is not running, the persistent volume keeps
the data around. If the cluster is destroyed or if the persistent volume claim
is deleted, the automatically created disk image will be garbage collected and
deleted. At that point all data will be lost.

    kubectl delete -f k8s/persistent-volumes.yml

Delete the storage class.

    kubectl delete -f k8s/storage-class.yml

ConfigMaps are managed explicitly for now:

    kubectl delete configmap prometheus-config

Now, `kubectl get` should not include any of the above objects.

    kubectl get services,deployments,pods,configmaps,pvc,pv

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
