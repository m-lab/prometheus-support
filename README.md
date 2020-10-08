[![Build Status][svg]][travis]

[svg]: https://travis-ci.org/m-lab/prometheus-support.svg?branch=master
[travis]: https://travis-ci.org/m-lab/prometheus-support

# prometheus-support

Prometheus configuration for M-Lab.

# Deploying Prometheus to Kubernetes

The following instructions presume there is already a kubernetes cluster
created in a GCP project and the cluster is accessible with `kubectl`.

See the [container engine quickstart guide][quickstart] for a simple howto.

[quickstart]: https://cloud.google.com/container-engine/docs/quickstart

# Creating a cluster for Prometheus

## Federation

To support service discovery across GCP, the cloud-platform scope is currently
necessary.

```
gcloud container \
  --project "mlab-sandbox" clusters create "prometheus-federation" \
  --zone "us-central1-a" \
  --machine-type=n1-standard-8 \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --num-nodes 3 \
  --enable-autorepair --enable-autoupgrade \
  --node-labels=prometheus-node=true
```

### Upgrade deployment resource limits

To increase the resources assigned to the prometheus server or the set of all
services, you may need a larger node pool.

```
gcloud --project=mlab-staging container node-pools create default-pool-N \
  --cluster=prometheus-federation \
  --num-nodes=3 \
  --zone=us-east1-c \
  --scopes "https://www.googleapis.com/auth/cloud-platform" \
  --node-labels=prometheus-node=true \
  --enable-autorepair --enable-autoupgrade \
  --machine-type=n1-standard-8
```

Adjust the project, cluster name, and zone as appropriate. If the cluster is
using static public IPs, use the same zone as the current cluster; static IPs
are associated with a single zone. It is necessary to configure a static IP
by going to:

    GCP -> VPC Networking -> External IP Addresses

and then configure Cloud DNS for your
`{grafana, prometheus, alertmanager}.<cluster>.measurementlab.net` subdomains
to point at that IP address:

    GCP -> Network Services -> Cloud DNS

in order for automatic TLS certificates to be generated.

Then update the resource "request" and "limit" in the appropriate deployment
configuration, as well as the IP address:

    `k8s/<project>/<cluster>/deployment/<deployment.yml>`

It may also be necessary to update the:

    GCP -> Networking -> Load Balancer -> Backend

to include the new node pool. Otherwise, network requests will appear to hang.

Also, k8s may fail to detach a peristent volume from one node pool and make it
available to the other. This will manifest as a deployment's pod
'CreatingContainer' indefinitely. And, the `kubectl get events` will include
related error messages.

## Within an existing cluster

No special scopes are required for the prometheus cluster configuration.
However, node labels can only be added to a new node group using the command
line.

For very large number of time series (e.g. production prometheus-federation) a
highmem node pool is necessary.

```
gcloud --project=mlab-oti container node-pools create prometheus-pool \
  --cluster=prometheus-federation \
  --num-nodes=2 \
  --zone=us-central1-a \
  --node-labels=prometheus-node=true \
  --enable-autorepair --enable-autoupgrade \
  --machine-type=n1-highmem-16
```

# Roles

Since k8s version 1.6, stricter access controls are the default.

Please understand the [RBAC permission model][rbac] and the objects they apply
to.

Before you can run either of the `apply-cluster.sh` or
`apply-global-prometheus.sh` scripts, your user account must have the
`cluster-admin` role.

To assign this role:
* You may assign yourself the 'cluster-admin' role directly for the cluster.

```
kubectl create clusterrolebinding additional-cluster-admins \
    --clusterrole=cluster-admin \
    --user=<your-email>
```

* You should assign the travis service account deployer as the cluster-admin.

```
kubectl create clusterrolebinding additional-cluster-admins \
    --clusterrole=cluster-admin \
    --user=<service-account-address>
```

[rbac]: https://kubernetes.io/docs/admin/authorization/rbac/

# Using Kubernetes config files

Kubernetes config files preserve a deployment configuration and provide a
convenient mechanism for review and automated deployments.

Some steps cannot be automated. For example, while a LoadBalancer can
automatically assign a public IP address to a service, it will not ([yet][dns])
update corresponding DNS records for that IP address. So, we must reserve a
static IP through the Cloud Console interface first.

*Also, note*: Only one GKE cluster at a time can use the static IPs allocated
in the `k8s/.../services.yml` files. If you are using an additional GKE cluster
(e.g.  in mlab-sandbox project), update the services yaml files to use the
new static IP allocation.

[dns]: https://github.com/kubernetes-incubator/external-dns

## ConfigMaps

Many services like prometheus provide canonical docker images published to
[Dockerhub][dockerhub] (or other registry). We can customize the deployment by
changing the configuration at run time using ConfigMaps. For detailed background
see the [official docs][configmaps].

Create the ConfigMap for prometheus (only create a ConfigMap for one of cluster
or federation, not both):

TODO(soltesz): move environment variables (like gcloud-project) to a separate
directory.

    # For federation.
    kubectl create configmap prometheus-federation-config \
        --from-literal=gcloud-project=mlab-sandbox \
        --from-file=config/federation/prometheus

    # For cluster.
    kubectl create configmap prometheus-cluster-config \
        --from-file=config/cluster/prometheus

Although the flag is named `--from-file`, it accepts a directory. With this
flag, kubernetes creates a ConfigMap with keys equal to the filenames, and
values equal to the content of the file.

    kubectl describe configmap prometheus-cluster-config

      Name:       prometheus-cluster-config
      Namespace:  default
      Labels:     <none>
      Annotations:    <none>

      Data
      ====
      prometheus.yml: 9754 bytes

We can now refer to this ConfigMap in the "deployment" configuration later. For
example, `k8s/mlab-sandbox/prometheus-federation/deployments/prometheus.yml`
uses a configmap as a volume so that the config file
`config/federation/prometheus.yml` appears under `/etc/prometheus`.

For example, this will look something like (with abbreviated configuration):

    - containers:
      ...
        volumeMounts:
          # /etc/prometheus/prometheus.yml should contain the M-Lab Prometheus
          # config.
          - mountPath: /etc/prometheus
            # This name refers to the 'volumes.name'
            name: prometheus-config
      volumes:
      - name: prometheus-config
        configMap:
          # This name refers to the configmap name.
          name: prometheus-federation-config

Note: Configmaps only support text data. Secrets may be an alternative for
binary data. https://github.com/kubernetes/kubernetes/issues/32432

[dockerhub]: https://hub.docker.com/r/prom/prometheus/
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
            /etc/prometheus from prometheus-cluster-config (rw)
            /legacy-targets from prometheus-storage (rw)
            /prometheus from prometheus-storage (rw)
          ...

### Update a ConfigMap

When the content of a configmap value needs to change, you can either delete and
create the configmap object (not ideal), or replace the new configuration all at
once.

    kubectl create configmap prometheus-federation-config --from-file=prometheus \
        --dry-run -o json | kubectl apply -f -

After updating a configmap, any pods that use this configmap will need to be
restarted for the change to take effect.

    podname=$( kubectl get pods -o name --selector='run=prometheus-server' )
    kubectl delete ${podname}

The deployment replica set will automatically recreate the pod and the new
prometheus server will use the updated configmap. This is a known issue:
https://github.com/kubernetes/kubernetes/issues/13488

Preferably the process (like prometheus) will support a 'reload' operation.
However, it can take several minutes for the configmap to be updated from the
perspective of the container. So, do not run reload until the configmap is up
to date. (TODO: how to confirm this from outside the container?)

# Using Kubernetes Secrets

Secrets are like ConfigMaps in that they can be a source for environment
variables and volume mounts. Unlike ConfigMaps, secrets contain confidential
material, like certificates, passwords, access tokens, or similar.

## Grafana secrets

The Grafana configuration needs a pre-defined password for the admin user.
Create one using a command like this:

```
kubectl create secret generic grafana-secrets \
    --from-literal=admin-password=[redacted text]
```

To recover the password:

```
jsonpath='{.items[?(@.metadata.name=="grafana-secrets")].data.admin-password}'
kubectl get secrets -o jsonpath="${jsonpath}" | base64 --decode && echo ''
```

# Create deployment

Before beginning, verify that you are [operating on the correct kubernetes
cluster][cluster].

Then, update `k8s/mlab-sandbox/prometheus-federation/deployments/prometheus.yml`
to reference the current stable prometheus container tag. Now, deploy the
service.

Create a storage class for GCE persistent disks:

    kubectl create -f k8s/mlab-sandbox/<cluster-name>/persistentvolumes/storage-class.yml

Create a persistent volume claim that Prometheus will bind to:

    kubectl create -f k8s/mlab-sandbox/<cluster-name>/persistentvolumes/persistent-volumes.yml

Note: Persistent volume claims are intended to exist longer than pods. This
allows persistent disks to be dynamically allocated and preserved across pod
creations and deletions.

Create a service using the public IP address that will send traffic to pods
with the label "run=prometheus-server":

    kubectl create -f k8s/mlab-sandbox/<cluser-name>/services

## Federation deployment

The cluster and federation deployments are mutually exclusive. Do not deploy
both to the same cluster.

The federation deployment is a super-set of the prometheus cluster deployment.
It is designed to monitor the local cluster as well as aggregate metrics from
other prometheus clusters.

    kubectl create -f k8s/mlab-sandbox/<cluster-name>/deployments/prometheus.yml

## Check deployment

After completing the above steps, you can view the status of all objects using
something like:

    kubectl get services,deployments,pods,configmaps,secrets,pvc,pv,events

`kubectl get` is your friend. See also `kubectl describe` for even more details.

[cluster]: https://cloud.google.com/container-engine/docs/clusters/operations
[setup]: #grafana-setup
[daemonset]: https://kubernetes.io/docs/admin/daemons/

# Custom Targets

With the M-Lab configuration, we can add or remove two kinds of targets at
runtime: legacy and federation targets.

Using the file service discovery configuration, we create a JSON or YAML input
file in the [correct form][file_sd_config], and copy the file into the pod
filesystem.

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

Copy file(s) to the correct directory in the prometheus pod.

    DIRECTORY=/legacy-targets
    podname=$( kubectl get pods -o name --selector='run=prometheus-server' )
    kubectl cp <filename.json> ${podname##*/}:${DIRECTORY}

To look at the available files the target directory:

    kubectl exec -c prometheus-server -t ${podname##*/} -- /bin/ls -l ${DIRECTORY}

Within five minutes, any file ending with `*.json` or `*.yaml` will be scanned
and the new targets should be reported by the prometheus server.

[file_sd_config]: https://prometheus.io/docs/operating/configuration/#file_sd_config

## Legacy Targets

For legacy targets (e.g. sidestream), copy the JSON file into the prometheus
container under the `/legacy-targets` directory.

In the Prometheus server, targets are listed under:

 * Status -> Targets -> "legacy-targets"

## Federation Targets

For federation targets (i.e. other prometheus services), copy the file to the
prometheus container under the `/federation-targets` directory.

In the Prometheus server, targets are listed under:

 * Status -> Targets -> "federation-targets"

# Delete deployment

Delete the prometheus deployment:

    kubectl delete -f k8s/mlab-sandbox/<cluster-name>/deployments/prometheus.yml

Since the prometheus pod is no longer running, clients connecting to the public
IP address will try to load but fail. If we also delete the service, then
traffic will stop being forwarded from the public IP altogether.

    kubectl delete -f k8s/mlab-sandbox/<cluster name>/services

Even if the prometheus deployment is not running, the persistent volume keeps
the data around. If the cluster is destroyed or if the persistent volume claim
is deleted, the automatically created disk image will be garbage collected and
deleted. At that point all data will be lost.

    kubectl delete -f k8s/mlab-sandbox/<cluster-name>/persistentvolumes/persistent-volumes.yml

Delete the storage class.

    kubectl delete -f k8s/mlab-sandbox/<cluster-name>/persistentvolumes/storage-class.yml

ConfigMaps are managed explicitly for now:

    kubectl delete configmap prometheus-cluster-config
    kubectl delete configmap prometheus-federation-config

Now, `kubectl get` should not include any of the above objects.

    kubectl get services,deployments,pods,configmaps,pvc,pv

# Grafana

## Create

Create ConfigMaps for grafana:

    kubectl create configmap grafana-config \
        --from-file=config/federation/grafana
    kubectl create configmap grafana-env \
        --from-literal=domain=<static ip address allocated from GCP console>

Note: the domain may be the public IP address, if there is no DNS name yet.

Create a secret to contain the Grafana admin password:

    kubectl create secret generic grafana-secrets \
        --from-literal=admin-password=[redacted text]

Finally, Create the grafana deployment. Like the prometheus deployment, this
step starts the grafana server.

    kubectl create -f k8s/mlab-sandbox/<cluster-name>/deployments/grafana.yml

## Setup

### Deleting provisioned datasources

Datasources are provisioned through YAML files located in
`config/federation/grafana/provisioning/datasources/`. Currently, Grafana does
not support having a provisioned datasource deleted automatically from the
database once its YAML file goes away.  The official way to delete a
provisioned datasource is to [add a `deleteDatasources` section]
(https://grafana.com/docs/administration/provisioning/#datasources) to the
provisioning YAML. However, this is cumbersome and awkward and somewhat
pollutes the git history. There is another way that is fairly manual, but not
hard.

In the configuration section of the Grafana Web interface, there is a section
for creating API keys. Create a temporary key that will expire after, say, 1d.
Then use that key to run a manual API request like the following, being sure to
replace `<api-key>` with your API key, `<datasource-id>` with the ID of the datasource,
`<datasource-name>` with the name of the datasource, and `<datasource-id>` in
the API URL to match the datasource ID. Don't forget to also make sure that the
API URL is prointing to the GCP project you intend. This command will flag the
datasource as editable:

```
curl --request PUT --header "Authorization: Bearer <api-key>" \
    --header "Content-Type: application/json" \
    --data '{"id": <datasource-id>, "name": "<datasource-name>", \
             "type": "prometheus", "access": "server", \
             "editable": "true"}' \
    https://grafana.mlab-sandbox.measurementlab.net/api/datasources/<datasource-id>
```

Now you can delete the datasource with something like the following, replacing
`<api-key>` with your API key, and changing the API URL to match the ID of the
datasource you want to delete:

```
curl --request DELETE --header "Authorization: Bearer <api-key>" \
    https://grafana.mlab-sandbox.measurementlab.net/api/datasources/<datasource-id>
```

## Delete

Delete the grafana deployment.

    kubectl delete -f k8s/mlab-sandbox/<cluster-name>/deployments/grafana.yml

Delete the grafana configmaps:

    kubectl delete configmap grafana-config
    kubectl delete configmap grafana-env

Delete the grafana secrets:

    kubectl delete secret grafana-secrets

# Alertmanager

The alertmanager configuration depends on the shared service and persistent
volume configurations. If those are already loaded, then continue to the steps
below.

Also, note: the alertmanager service will do nothing unless the prometheus
deployment includes the command line argument that directs alerts to this
instance of the alertmanager. i.e. `-alertmanager.url=http://bobloblaw.com:9093`

## Create

If you're setting up the alertmanager for the first time, copy
`config.yml.template` to create `config.yml` and update the `api_uri` entries
with real values. See the template comments for how to do that.

Create the configmaps for alertmanager:

    kubectl create configmap alertmanager-config \
        --from-file=config/federation/alertmanager

    kubectl create configmap alertmanager-env \
        --from-literal=external-url=http://<public ip address>:9093

Create the alertmanager deployment.

    kubectl create -f k8s/mlab-sandbox/<cluster-name>/deployments/alertmanager.yml

## Delete

Delete the deployment.

    kubectl delete -f k8s/mlab-sandbox/<cluster-name>/deployments/alertmanager.yml

Delete the configmaps.

    kubectl delete configmap alertmanager-config
    kubectl delete configmap alertmanage-env

# Github Receiver

The github receiver implements the Alertmanager Webhook API. So, Alertmanager
can send alerts to the github receiver and they are converted into Github
issues.

The github receiver authenticates using Github access tokens. Generate a new one
at: https://github.com/settings/tokens

Actions authenticated using the token will be associated with your account.

Note: only one github receiver should target a given github repository.

## Create

Create the secrets for the github receiver:

    kubectl create secret generic github-secrets \
        --from-literal=auth-token=${AUTH_TOKEN}

Create the service and deployment:

    kubectl create -f k8s/mlab-oti/<cluster-name>/services/github-receiver-service.yml
    kubectl create -f k8s/mlab-oti/<cluster-name>/deployments/github-receiver.yml

## Delete

Delete the service and deployment.

    kubectl delete -f k8s/mlab-oti/<cluster-name>/services/github-receiver-service.yml
    kubectl delete -f k8s/mlab-oti/<cluster-name>/deployments/github-receiver.yml

Delete the secrets:

    kubectl delete secret github-secrets

# Blackbox exporter

The blackbox exporter allows probes of endpoints over HTTP, HTTPS, DNS, TCP and
ICMP.

Targets are declared in an input file like legacy targets, however
blackbox targets require specifying a "module". The module name must match a
module defined in `config/federation/blackbox/config.yml`. Different modules
have different format requirements on the targets (e.g. some with ports, some
without).

```
[
    {
        "labels": {
            "module": "ssh_v4_online",
            "service": "sshalt"
        },
        "targets": [
            "mlab1.den02.measurement-lab.org:806",
            "mlab4.den02.measurement-lab.org:806"
        ]
    }
]
```

A single input file can define a list of configurations, each with a different
"module" and independent list of targets.

## Create

Create the configmaps for the blackbox exporter:

    kubectl create configmap blackbox-config \
        --from-file=config/federation/blackbox

Create the blackbox exporter deployment.

    kubectl create -f k8s/mlab-sandbox/<cluster-name>/deployments/blackbox.yml

## Delete

Delete the deployment.

    kubectl delete -f k8s/mlab-sandbox/<cluster-name>/deployments/blackbox.yml

Delete the configmaps.

    kubectl delete configmap blackbox-config

## Static outbound IP pinning

There are currently two services running in the cluster which require that
all outbound requests come from a static source IP: reboot-api and
script-exporter. The reboot-api needs a static outbound IP address because it
may need to reboot a node via the iDRAC and a firewall rule on the switch
prevents access to the DRACs, except from a few permitted IPs. The
script-exporter needs a static outbound IP because one of the things it does
is to run e2e NDT tests, and we need a predetermined source IP address so that
internal, e2e testing can be easily removed from the data we publish.

We're going to create a two-node pool, make sure only services that need
static outbound IPs run on it, and then use a service called
[kubeIP](https://github.com/doitintl/kubeip) to assign static IPs to its
nodes.

### Create pool

Create a two-node pool with a specific label (to make sure that any necessary
pods can be selected onto it) and taint (to make sure other services are not
run on it):

```
gcloud container node-pools create static-outbound-ip \
--cluster=prometheus-federation --machine-type=n1-standard-8 --num-nodes=2 \
--node-labels=outbound-ip=static --node-taints=outbound-ip=static:NoSchedule
```

### Create kubeIP credentials

Create gcloud service-account for kubeIP:

```
gcloud iam service-accounts create kubeip-service-account --display-name "kubeIP"
```

Create role and attach the service-account to it:

```
gcloud --project ${GCLOUD_PROJECT} \
    iam roles create kubeip --file config/federation/kubeip/roles.yml
gcloud --project ${GCLOUD_PROJECT} \
    projects add-iam-policy-binding $GCLOUD_PROJECT \
    --member serviceAccount:kubeip-service-account@$GCLOUD_PROJECT.iam.gserviceaccount.com \
    --role projects/$GCLOUD_PROJECT/roles/kubeip
```

Grab a key file for the service-account:

```
gcloud --project ${GCLOUD_PROJECT} \
    iam service-accounts keys create key.json --iam-account \
    kubeip-service-account@${GCLOUD_PROJECT}.iam.gserviceaccount.com
```

And then turn it into a Kubernetes secret, after making sure the right project
is selected for kubectl:

```
gcloud container clusters get-credentials prometheus-federation `
    --zone us-central1-a --project ${GCLOUD_PROJECT}

kubectl create secret generic kubeip-key --from-file=key.json
```

Finally reserve static IPs for your new nodepool:

```
for i in {1..2}; do
    gcloud --project ${GCLOUD_PROJECT} \
        compute addresses create kubeip-ip$i --region=us-central1
done
```

And label them for kubeIP (use the same region as the GKE cluster). The
label `kubeip=prometheus-federation` corresponds to the `KUBEIP_LABELKEY`
and `KUBEIP_LABELVALUE` values in the kubeIP deployment:

```
for i in {1..2}; do
    gcloud --project ${GCLOUD_PROJECT} \
        beta compute addresses update kubeip-ip$i \
        --update-labels kubeip=prometheus-federation --region=us-central1
done
```

Then continue your deployment as normal.

# Pushgateway

A prometheus push gateway are useful for short-lived processes, or processes
that are not network accessible by the prometheus server.

Note that push gateways have limitations. So, consider this an option of last
resort and understand the limits before proceeding.

For more information, see:
https://github.com/prometheus/pushgateway#prometheus-pushgateway

## Create

The pushgateway has no configuration file or persistent state. Create the
deployment.

    kubectl create -f k8s/mlab-sandbox/<cluster-name>/deployments/pushgateway.yml

## Delete

Delete the deployment.

    kubectl delete -f k8s/mlab-sandbox/<cluster-name>/deployments/pushgateway.yml

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

## Viewing events

Kubernetes events are also an good source of recent actions and their status.
For example, if we tried to create the grafana deployment before defining the
grafana-secrets secret, the pods would fail to start and the events would
include a more specific error message.

```
$ kubectl get pods,events
NAME                                    READY     STATUS    RESTARTS   AGE
po/grafana-server-1476781881-fhr5z      0/1       RunContainerError   0          6m

LASTSEEN   FIRSTSEEN   COUNT     NAME                                 KIND      SUBOBJECT                         TYPE      REASON       SOURCE                                                    MESSAGE
55s        7m          29        ev/grafana-server-1476781881-fhr5z   Pod                                         Warning   FailedSync   {kubelet gke-soltesz-test-2-default-pool-7151d92d-7dd5}   Error syncing pod, skipping: failed to "StartContainer" for "grafana-server" with RunContainerError: "GenerateRunContainerOptions: secrets \"grafana-secrets\" not found"
```
