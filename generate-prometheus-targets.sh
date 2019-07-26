#!/bin/bash

set -euxo pipefail

# Root directory of this script.
BASEDIR=${PWD}

# Create all output directories.
for project in mlab-sandbox mlab-staging mlab-oti ; do
  mkdir -p ${BASEDIR}/gen/${project}/prometheus/{legacy-targets,blackbox-targets,blackbox-targets-ipv6,snmp-targets,script-targets}
done

# All testing sites and machines.
SELECT_mlab_sandbox=$( cat ${BASEDIR}/testing_patterns.txt | xargs | sed -e 's/ /|/g' )

# All staging sites and machines.
SELECT_mlab_staging=$( cat ${BASEDIR}/staging_patterns.txt | xargs | sed -e 's/ /|/g' )

# All sites *excluding* test sites.
SELECT_mlab_oti=$( cat ${BASEDIR}/production_patterns.txt | xargs | sed -e 's/ /|/g' )

# GCP doesn't support IPv6, so we have a Linode VM running three instances of
# the blackbox_exporter, on three separate ports... one port/instance for each
# project. These variables map projects to ports, and will be transmitted to
# Prometheus in the form of a new label that will be rewritten.
BBE_IPV6_PORT_mlab_oti="9115"
BBE_IPV6_PORT_mlab_staging="8115"
BBE_IPV6_PORT_mlab_sandbox="7115"

# Fetch mlabconfig.py from the siteinfo repo.
# TODO: Replace curl with a native go-get once mlabconfig is rewritten in Go.
curl --location "https://raw.githubusercontent.com/m-lab/siteinfo/sandbox-roberto-mlabconfig-bmc/cmd/mlabconfig.py" > \
    ./mlabconfig.py
chmod +x ./mlabconfig.py


for project in mlab-sandbox mlab-staging mlab-oti ; do
  output=${BASEDIR}/gen/${project}/prometheus

  # Construct the per-project SELECT variable name to use below.
  pattern=SELECT_${project/-/_}

  # Construct the per-project blackbox_exporter port variable to use below.
  # blackbox_exporter on for IPv6 targets.
  bbe_port=BBE_IPV6_PORT_${project/-/_}

  ########################################################################
  # Note: The following configs select all servers. This allows us to
  # experiment with monitoring many sites in sandbox or staging before
  # production.
  ########################################################################

  # ndt7 SSL on port 443 over IPv4
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:443 \
      --label service=ndt7 \
      --label module=tcp_v4_online \
      --select "ndt.iupui.(${!pattern})" > \
          ${output}/blackbox-targets/ndt7.json

  # ndt7 SSL on port 443 over IPv6
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:443 \
      --label service=ndt7_ipv6 \
      --label module=tcp_v6_online \
      --label __blackbox_port=${!bbe_port} \
      --select "ndt.iupui.(${!pattern})" \
      --decoration "v6" > \
          ${output}/blackbox-targets-ipv6/ndt7_ipv6.json

  # NDT "raw" on port 3001 over IPv4
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:3001 \
      --label service=ndt_raw \
      --label module=tcp_v4_online \
      --select "ndt.iupui.(${!pattern})" > \
          ${output}/blackbox-targets/ndt_raw.json

  # NDT "raw" on port 3001 over IPv6
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:3001 \
      --label service=ndt_raw_ipv6 \
      --label module=tcp_v6_online \
      --label __blackbox_port=${!bbe_port} \
      --select "ndt.iupui.(${!pattern})" \
      --decoration "v6" > \
          ${output}/blackbox-targets-ipv6/ndt_raw_ipv6.json

  # NDT SSL on port 3010 over IPv4
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:3010 \
      --label service=ndt_ssl \
      --label module=tcp_v4_tls_online \
      --use_flatnames \
      --select "ndt.iupui.(${!pattern})" > \
          ${output}/blackbox-targets/ndt_ssl.json

  # NDT SSL on port 3010 over IPv6
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:3010 \
      --label service=ndt_ssl_ipv6 \
      --label module=tcp_v6_tls_online \
      --label __blackbox_port=${!bbe_port} \
      --use_flatnames \
      --select "ndt.iupui.(${!pattern})" \
      --decoration "v6" > \
          ${output}/blackbox-targets-ipv6/ndt_ssl_ipv6.json

  # script_exporter for NDT end-to-end monitoring
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}} \
      --label service=ndt_e2e \
      --use_flatnames \
      --select "ndt.iupui.(${!pattern})" > \
          ${output}/script-targets/ndt_e2e.json

  # script_exporter for NDT queueing check
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}} \
      --label service=ndt_queue \
      --use_flatnames \
      --select "ndt.iupui.(${!pattern})" > \
          ${output}/script-targets/ndt_queue.json

  # Mobiperf on ports 6001, 6002, 6003 over IPv4.
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:6001 \
      --template_target={{hostname}}:6002 \
      --template_target={{hostname}}:6003 \
      --label service=mobiperf \
      --label module=tcp_v4_online \
      --physical \
      --select "1.michigan.(${!pattern})" > \
          ${output}/blackbox-targets/mobiperf.json

  # Mobiperf on ports 6001, 6002, 6003 over IPv6.
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:6001 \
      --template_target={{hostname}}:6002 \
      --template_target={{hostname}}:6003 \
      --label service=mobiperf_ipv6 \
      --label module=tcp_v6_online \
      --label __blackbox_port=${!bbe_port} \
      --physical \
      --select "1.michigan.(${!pattern})" \
      --decoration "v6" > ${output}/blackbox-targets-ipv6/mobiperf_ipv6.json

  # neubot on port 9773 over IPv4.
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:9773/sapi/state \
      --label service=neubot \
      --label module=neubot_online_v4 \
      --physical \
      --select "neubot.mlab.(${!pattern})" > \
          ${output}/blackbox-targets/neubot.json

  # neubot on port 9773 over IPv6.
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:9773/sapi/state \
      --label service=neubot_ipv6 \
      --label module=neubot_online_v6 \
      --label __blackbox_port=${!bbe_port} \
      --physical \
      --select "neubot.mlab.(${!pattern})" \
      --decoration "v6" > ${output}/blackbox-targets-ipv6/neubot_ipv6.json

  # snmp_exporter on port 9116.
  ./mlabconfig.py --format=prom-targets-sites \
      --physical \
      --select "${!pattern}" \
      --template_target=s1.{{sitename}}.measurement-lab.org \
      --label service=snmp > \
          ${output}/snmp-targets/snmpexporter.json

  # inotify_exporter for NDT on port 9393.
  ./mlabconfig.py --format=prom-targets \
      --template_target={{hostname}}:9393 \
      --label service=inotify \
      --physical \
      --select "ndt.iupui.(${!pattern})" > \
          ${output}/legacy-targets/ndt_inotify.json

  # node_exporter on port 9100.
  ./mlabconfig.py --format=prom-targets-nodes \
      --template_target={{hostname}}:9100 \
      --label service=nodeexporter \
      --select "${!pattern}" > \
          ${output}/legacy-targets/nodeexporter.json

  # ICMP probe for platform switches
  ./mlabconfig.py --format=prom-targets-sites \
      --physical \
      --select "${!pattern}" \
      --template_target=s1.{{sitename}}.measurement-lab.org \
      --label module=icmp > \
          ${output}/blackbox-targets/switches_ping.json

  # SSH on port 22 over IPv4
  ./mlabconfig.py --format=prom-targets-nodes \
      --template_target={{hostname}}:22 \
      --label service=ssh \
      --label module=ssh_v4_online \
      --physical \
      --select "${!pattern}" > ${output}/blackbox-targets/ssh.json

  # SSH on port 22 over IPv6
  ./mlabconfig.py --format=prom-targets-nodes \
      --template_target={{hostname}}:22 \
      --label service=ssh \
      --label module=ssh_v6_online \
      --label __blackbox_port=${!bbe_port} \
      --physical \
      --select "${!pattern}" \
      --decoration "v6" > ${output}/blackbox-targets-ipv6/ssh_ipv6.json

done
