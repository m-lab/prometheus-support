# IPv6 Monitoring

Google Cloud Platform fully supports IPv6, however, the prometheus-federation
GKE cluster is deployed into the default, auto-mode VPC network, which doesn't
support IPv6. It would be a pretty big and possibly disruptive operation to
redeploy the entire cluster in a new custom, dual stack subnet. An easier and
faster way to get around this constraint is to simply deploy a dual stack GCE
instance in each project that runs blackbox_exporter, which Prometheus will
query over IPv4 in order to probe IPv6 targets.

Prior to around May of 2026, this was the same basic configuration that was in
use, but instead of running blackbox_exporter on a GCE instance, it was run on
a Linode VM. This new configuration keeps that same basic pattern, but gets rid
of the Linode VM in favor of a GCE instance in each project.

The blackbox_exporter instances get automatically deployed to the GCE instances
via builds of this repository (the deploy_bbe_config.sh script).

When resources and time permit, we should probably consider redeploying the
prometheus-federation cluster in VPC subnet that supports IPv6 so that all
blackbox_exporter instances live in the prometheus-federation cluster.

