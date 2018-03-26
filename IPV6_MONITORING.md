# IPv6 Monitoring

Google Cloud Platform does not currently support IPv6 for most applications.
Since Prometheus and the Prometheus blackbox\_exporter both run in GCP, we need
another solution for IPv6 monitoring. The solution we decided to use is to run
the blackbox\_exporter on a separate VM through a provider that does support
IPv6. Since we are already using Linode.com for a few other things, we deployed
the VM on Linode.

Any base Linux distribution would probably be just fine, but this deployment is
using Debian 9.

Below are first-time setup instructions and requirements for the VM:

* Request a `/116` IPv6 pool from Linode by opening a support ticket. In our
  case, we were given this prefix `2600:3c02::17:d000/116`.

* Through the Linode Manager (Web interface), select the Linode, then select
  "Edit" for the configuration profile in use. Disable `Auto-Configure
  Networking`.

* [Install Docker](https://docs.docker.com/install/linux/docker-ce/debian/),
  since the blackbox\_exporter will be running in a Docker container.

* Create a new user named "mlab" (`# adduser mlab`) and it to the group `docker`
  (`# adduser mlab docker`).

* Add the public SSH key for the Travis deployer to mlab's
  *~/.ssh/authorized_keys* file. The public key, and the private one, can be
  found in the M-Lab *shared_data* repository in the *ssh-keys/* directory.

* [Enable NDP
  proxying](https://docs.docker.com/v17.09/engine/userguide/networking/default_network/ipv6/#using-ndp-proxying)
  for the `eth0` interface: `# sysctl net.ipv6.conf.eth0.proxy_ndp=1`. Add this
  to _/etc/sysctl.conf_ to persist the change across reboots. **NOTE**: Having
  to enable NDP proxying is a consequence of using a `/116` IPv6 prefix. If we
  were using a fully routable `/64` prefix, this wouldn't be necessary.

* Configure IPv6 for the `eth0` interface in _/etc/network/interfaces_ using the
  prefix we got. We are going to subnet our prefix into two subnets, one for the
  VM and one for Docker containers. After this change, restart networking (`#
  systemctl restart networking`). 

```
iface eth0 inet6 static
    address 2600:3c02::17:d001/117 
    gateway fe80::1
    # These are the IPs of the three Docker containers.
    post-up ip -6 neigh add proxy 2600:3c02::17:d802 dev eth0
    post-up ip -6 neigh add proxy 2600:3c02::17:d803 dev eth0
    post-up ip -6 neigh add proxy 2600:3c02::17:d804 dev eth0
```
* Create the file _/etc/docker/daemon.json_ with the following content, and then
  restart Docker (`# systemctl restart docker`):

```
{
    "ipv6": true,
    "fixed-cidr-v6": "2600:3c02::17:d800/117"
}
```
* Pull the blackbox\_exporter Docker image: `$ docker pull
  prom/blackbox-exporter`.

* Manually upload [the blackbox\_exporter config
  file](https://github.com/m-lab/prometheus-support/blob/master/config/federation/blackbox/config.yml)
  to mlab's home directory, then make three copies of it with the following
  names. If you don't do this, instantiating the Docker instances will fail
  because the blackbox\_exporter will not be able to find its config file.
  Later, these files will be [pushed to the VM automatically on
  builds](https://github.com/m-lab/prometheus-support/blob/master/deploy_bbe_config.sh)
  of m-lab/prometheus-support repo.
```
blackbox-exporter-config-mlab-sandbox.yml
blackbox-exporter-config-mlab-staging.yml
blackbox-exporter-config-mlab-oti.yml
```
* Instantiate the Docker containers (as the user mlab). **NOTE**: it is very
  important to include the `--restart always` flag and argument. Without it, if
  the machine is rebooted or the container crashes, then it won't start again
  automatically.
```
$ docker run --detach --publish 7115:9115 --volume `pwd`:/config \
    --restart always --name mlab-sandbox prom/blackbox-exporter \
    --config.file=/config/blackbox-exporter-config-mlab-sandbox.yml

$ docker run --detach --publish 8115:9115 --volume `pwd`:/config \
    --restart always --name mlab-staging prom/blackbox-exporter \
    --config.file=/config/blackbox-exporter-config-mlab-staging.yml

$ docker run --detach --publish 9115:9115 --volume `pwd`:/config \
    --restart always --name mlab-oti prom/blackbox-exporter \
    --config.file=/config/blackbox-exporter-config-mlab-oti.yml
```
