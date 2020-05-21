#!/bin/bash

set -euxo pipefail

# Root directory of this script.
BASEDIR=${PWD}

# Create all output directories.
for project in mlab-sandbox mlab-staging mlab-oti ; do
  mkdir -p ${BASEDIR}/gen/${project}/prometheus/{legacy-targets,blackbox-targets,blackbox-targets-ipv6,snmp-targets,script-targets,bmc-targets,switch-monitoring-targets}
done

# GCP doesn't support IPv6, so we have a Linode VM running three instances of
# the blackbox_exporter, on three separate ports... one port/instance for each
# project. These variables map projects to ports, and will be transmitted to
# Prometheus in the form of a new label that will be rewritten.
BBE_IPV6_PORT_mlab_oti="9115"
BBE_IPV6_PORT_mlab_staging="8115"
BBE_IPV6_PORT_mlab_sandbox="7115"

# Fetch mlabconfig.py from the siteinfo repo.
# TODO: Replace curl with a native go-get once mlabconfig is rewritten in Go.
curl --location "https://raw.githubusercontent.com/m-lab/siteinfo/master/cmd/mlabconfig.py" > \
    ./mlabconfig.py
chmod +x ./mlabconfig.py


for project in mlab-sandbox mlab-staging mlab-oti ; do
  sites="https://siteinfo.${project}.measurementlab.net/v2/sites/sites.json"

  output=${BASEDIR}/gen/${project}/prometheus

  # Construct the per-project blackbox_exporter port variable to use below.
  # blackbox_exporter on for IPv6 targets.
  bbe_port=BBE_IPV6_PORT_${project/-/_}

  # ndt7 SSL on port 443 over IPv4
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:443 \
      --label service=ndt7 \
      --label module=tcp_v4_online \
      --project "${project}" \
      --select "ndt.iupui" > \
          ${output}/blackbox-targets/ndt7.json

  # ndt7 SSL on port 443 over IPv6
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:443 \
      --label service=ndt7_ipv6 \
      --label module=tcp_v6_online \
      --label __blackbox_port=${!bbe_port} \
      --project "${project}" \
      --select "ndt.iupui" \
      --decoration "v6" > \
          ${output}/blackbox-targets-ipv6/ndt7_ipv6.json

  # NDT "raw" on port 3001 over IPv4
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:3001 \
      --label service=ndt_raw \
      --label module=tcp_v4_online \
      --project "${project}" \
      --select "ndt.iupui" > \
          ${output}/blackbox-targets/ndt_raw.json

  # NDT "raw" on port 3001 over IPv6
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:3001 \
      --label service=ndt_raw_ipv6 \
      --label module=tcp_v6_online \
      --label __blackbox_port=${!bbe_port} \
      --project "${project}" \
      --select "ndt.iupui" \
      --decoration "v6" > \
          ${output}/blackbox-targets-ipv6/ndt_raw_ipv6.json

  # NDT SSL on port 3010 over IPv4
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:3010 \
      --label service=ndt_ssl \
      --label module=tcp_v4_tls_online \
      --project "${project}" \
      --select "ndt.iupui" > \
          ${output}/blackbox-targets/ndt_ssl.json

  # NDT SSL on port 3010 over IPv6
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:3010 \
      --label service=ndt_ssl_ipv6 \
      --label module=tcp_v6_tls_online \
      --label __blackbox_port=${!bbe_port} \
      --project "${project}" \
      --select "ndt.iupui" \
      --decoration "v6" > \
          ${output}/blackbox-targets-ipv6/ndt_ssl_ipv6.json

  # script-exporter for e2e monitoring with access tokens.
  ./mlabconfig.py --format=prom-targets-nodes \
      --sites="${sites}" \
      --template_target={{hostname}} \
      --label service=ndt5_client \
      --label experiment=ndt.iupui \
      --project "${project}" > \
          ${output}/script-targets/ndt5_client.json

  # neubot on port 80 over IPv4
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:80 \
      --label service=neubot \
      --label module=tcp_v4_online \
      --project "${project}" \
      --select "neubot.mlab" > \
          ${output}/blackbox-targets/neubot.json

  # neubot on port 80 over IPv6
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:80 \
      --label service=neubot_ipv6 \
      --label module=tcp_v6_online \
      --label __blackbox_port=${!bbe_port} \
      --decoration "v6" \
      --project "${project}" \
      --select "neubot.mlab" > \
          ${output}/blackbox-targets-ipv6/neubot_ipv6.json

  # neubot TLS on port 443 over IPv4
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:443 \
      --label service=neubot_tls \
      --label module=tcp_v4_tls_online \
      --project "${project}" \
      --select "neubot.mlab" > \
          ${output}/blackbox-targets/neubot_tls.json

  # neubot TLS on port 443 over IPv6
  ./mlabconfig.py --format=prom-targets \
      --sites "${sites}" \
      --template_target={{hostname}}:443 \
      --label service=neubot_tls_ipv6 \
      --label module=tcp_v6_tls_online \
      --label __blackbox_port=${!bbe_port} \
      --decoration "v6" \
      --project "${project}" \
      --select "neubot.mlab" > \
          ${output}/blackbox-targets-ipv6/neubot_tls_ipv6.json

  # snmp_exporter on port 9116.
  ./mlabconfig.py --format=prom-targets-sites \
      --sites "${sites}" \
      --physical \
      --template_target=s1.{{sitename}}.measurement-lab.org \
      --label service=snmp > \
          ${output}/snmp-targets/snmpexporter.json

  # ICMP probe for platform switches
  ./mlabconfig.py --format=prom-targets-sites \
      --sites "${sites}" \
      --physical \
      --template_target=s1.{{sitename}}.measurement-lab.org \
      --label module=icmp > \
          ${output}/blackbox-targets/switches_ping.json

  # SSH on port 22 over IPv4
  ./mlabconfig.py --format=prom-targets-nodes \
      --sites "${sites}" \
      --template_target={{hostname}}:22 \
      --label service=ssh \
      --label module=ssh_v4_online \
      --physical \
      --project "${project}" > ${output}/blackbox-targets/ssh.json

  # SSH on port 22 over IPv6
  ./mlabconfig.py --format=prom-targets-nodes \
      --sites "${sites}" \
      --template_target={{hostname}}:22 \
      --label service=ssh \
      --label module=ssh_v6_online \
      --label __blackbox_port=${!bbe_port} \
      --physical \
      --project "${project}" \
      --decoration "v6" > ${output}/blackbox-targets-ipv6/ssh_ipv6.json

  # BMC monitoring via the Reboot API
  ./mlabconfig.py --format=prom-targets-nodes \
      --sites "${sites}" \
      --template_target={{hostname}} \
      --label service=bmc_e2e \
      --physical \
      --project "${project}" \
      --decoration "d" > ${output}/bmc-targets/bmc_e2e.json

  # switch configuration monitoring via switch-monitoring.
  ./mlabconfig.py --format=prom-targets-sites \
      --sites "${sites}" \
      --physical \
      --template_target=s1.{{sitename}}.measurement-lab.org \
      --label service=switch-monitoring > \
          ${output}/switch-monitoring-targets/switch-monitoring.json

done
