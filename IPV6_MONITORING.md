# IPv6 Monitoring

Google Cloud Platform does not currently support IPv6 for most applications.
Since Prometheus and the Prometheus blackbox\_exporter both run in GCP, we need
another solution for IPv6 monitoring. The solution we decided to use is to run
the blackbox\_exporter on a separate VM through a provider that does support
IPv6. Since we are already using Linode.com for a few other things, we deployed
the VM on Linode.

Any base Linux distribution would probably be just fine, but this deployment is
using Debian 10.

Below are first-time setup instructions and requirements for the VM:

* Request a `/64` IPv6 pool from Linode by opening a support ticket. In our
  case, we were given this prefix `2600:3c02:e000:0185::/64`.
* [Install Docker](https://docs.docker.com/install/linux/docker-ce/debian/),
  since the blackbox\_exporter will be running in a Docker container.
* Create a new user named "mlab" (`# adduser mlab`) and it to the group `docker`
  (`# adduser mlab docker`).
* Add the public SSH key for the Travis deployer to mlab's
  *~/.ssh/authorized_keys* file. The public key, and the private one, can be
  found in the M-Lab *shared_data* repository in the *ssh-keys/* directory.
* Create the file _/etc/docker/daemon.json_ with the following content, and then
  restart Docker (`# systemctl restart docker`):

```json
{
    "ipv6": true,
    "fixed-cidr-v6": "2600:3c02:e000:0185::/64"
}
```

* Pull the blackbox\_exporter Docker image: `$ docker pull
  prom/blackbox-exporter:v0.12.0`.

* Manually upload [the blackbox\_exporter config
  file](https://github.com/m-lab/prometheus-support/blob/main/config/federation/blackbox/config.yml.template)
  to mlab's home directory, then make three copies of it with the following
  names. If you don't do this, instantiating the Docker instances will fail
  because the blackbox\_exporter will not be able to find its config file.
  Later, these files will be [pushed to the VM automatically on
  builds](https://github.com/m-lab/prometheus-support/blob/main/deploy_bbe_config.sh)
  of m-lab/prometheus-support repo.

```text
blackbox-exporter-config-mlab-sandbox.yml
blackbox-exporter-config-mlab-staging.yml
blackbox-exporter-config-mlab-oti.yml
```

* Instantiate the Docker containers (as the user mlab, `pwd` must be /home/mlab).
  **NOTE**: it is very important to include the `--restart always` flag and argument.
  Without it, if the machine is rebooted or the container crashes, then it won't
  start again automatically.

```shell
$ docker run --detach --publish 7115:9115 --volume `pwd`:/config \
    --restart always --name mlab-sandbox prom/blackbox-exporter:v0.12.0 \
    --config.file=/config/blackbox-exporter-config-mlab-sandbox.yml

$ docker run --detach --publish 8115:9115 --volume `pwd`:/config \
    --restart always --name mlab-staging prom/blackbox-exporter:v0.12.0 \
    --config.file=/config/blackbox-exporter-config-mlab-staging.yml

$ docker run --detach --publish 9115:9115 --volume `pwd`:/config \
    --restart always --name mlab-oti prom/blackbox-exporter:v0.12.0 \
    --config.file=/config/blackbox-exporter-config-mlab-oti.yml
```

* Install node\_exporter so that we can scrape metrics from this machine.

$ sudo apt install prometheus-node-exporter

Then edit /etc/default/prometheus-node-exporter, comment out the existing ARGS
definition, and add this one:

ARGS="-collectors.enabled=filesystem,loadavg,meminfo,netdev"

Restart node-exporter:

$ sudo systemctl restart prometheus-node-exporter
