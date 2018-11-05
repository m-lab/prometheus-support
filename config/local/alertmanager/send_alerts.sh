alerts1='[
  {
    "labels": {
       "alertname": "ExampleAlertFiring",
       "dev": "sda1",
       "instance": "alert.example.com:9099",
       "severity": "ticket"
     },
     "annotations": {
        "summary": "This is the summary of the example alert.",
        "description": "This is a longer *description* of what to do or what this alert means. For example, be sure to check the thing with the doodad and restart after logging all the steps.",
        "dashboard": "https://grafana.mlab-sandbox.measurementlab.net/d/000000187/soltesz-testing"
      }
  }
]'
junk2='[
  {
    "labels": {
       "alertname": "DiskRunningFull",
       "dev": "sda2",
       "instance": "instance1",
       "severity": "page",
        "repo": "public-issue-test"
     },
     "annotations": {
        "description": "The disk sda2 is running full.",
        "summary": "Please check the instance example1."
      }
  }
]'
junk=',
  {
    "labels": {
       "alertname": "DiskRunningFull",
       "dev": "sda1",
       "instance": "example2",
        "repo": "public-issue-test"
     },
     "annotations": {
        "info": "The disk sda1 is running full",
        "summary": "please check the instance example2"
      }
  },
  {
    "labels": {
       "alertname": "DiskRunningFull",
       "dev": "sdb2",
       "instance": "example2",
        "repo": "public-issue-test"
     },
     "annotations": {
        "info": "The disk sdb2 is running full",
        "summary": "please check the instance example2"
      }
  },
  {
    "labels": {
       "alertname": "DiskRunningFull",
       "dev": "sda1",
       "instance": "example3",
       "severity": "critical"
     }
  },
  {
    "labels": {
       "alertname": "DiskRunningFull",
       "dev": "sda1",
       "instance": "example3",
       "severity": "warning"
     }
  }
]'
alerts2='[
  {
    "labels": {
       "alertname": "DiskRunningFull",
       "dev": "sda3",
       "instance": "example4"
     }
  }
]'
alerts3='[
  {
    "labels": {
       "alertname": "MemoryAlmostFull",
       "dev": "sda1",
       "instance": "example1"
     }
  },
  {
    "labels": {
       "alertname": "CPUTooHigh",
       "instance": "example3"
     }
  }
]'
alerts4='[
  {
    "labels": {
       "alertname": "MemoryAlmostFull",
       "dev": "sdb2",
       "instance": "example2"
     }
  },
  {
    "labels": {
       "alertname": "CPUTooHigh",
       "instance": "example4"
     }
  }
]'
curl -XPOST -d"$alerts1" http://localhost:9093/api/v1/alerts
#curl -XPOST -d"$junk2" http://localhost:9093/api/v1/alerts
echo ''
#while true ; do
#curl -XPOST -d"$alerts3" http://localhost:9093/api/v1/alerts
#echo ''
#sleep 240
#done
#curl -XPOST -d"$alerts3" http://localhost:9093/api/v1/alerts
#curl -XPOST -d"$alerts4" http://localhost:9093/api/v1/alerts
#curl -XPOST -d"$alerts1" http://localhost:9095/api/v1/alerts
