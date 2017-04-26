// mlab_service_discovery contacts the AppEngine Admin API to finds all
// AppEngine Flexible Environments VMs in a RUNNING and SERVING state.
// mlab_service_discovery generates a JSON targets file based on the VM
// metadata suitable for input to prometheus.
//
// TODO:
//   * run continuously as a daemon.
//   * bundled process in a docker container and deploy with the prometheus pod.
//   * generalize to read from generic web sources.

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net/http"
	"regexp"
	"strings"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"

	appengine "google.golang.org/api/appengine/v1"
)

const (
	aefLabel             = "__aef_"
	aefLabelProject      = aefLabel + "project"
	aefLabelService      = aefLabel + "service"
	aefLabelVersion      = aefLabel + "version"
	aefLabelInstance     = aefLabel + "instance"
	aefLabelPublicProto  = aefLabel + "public_protocol"
	aefMaxTotalInstances = aefLabel + "max_total_instances"
	aefVmDebugEnabled    = aefLabel + "vm_debug_enabled"
)

var (
	defaultScopes = []string{appengine.CloudPlatformScope, appengine.AppengineAdminScope}
)

var (
	project   = flag.String("project", "mlab-sandbox", "project name")
	filename  = flag.String("filename", "output.json", "File name to write output targets file.")
	scopeList = flag.String("scopes", strings.Join(defaultScopes, ","), "Comma separated list of scopes to use.")
)

// discovery bundles runtime several variables together.
type discovery struct {
	project string

	client *http.Client
	apis   *appengine.APIService
}

// formatTargets generates a JSON string from the slice of maps provided.
func formatTargets(targets interface{}) string {
	b, err := json.MarshalIndent(targets, "", "    ")
	if err != nil {
		fmt.Println("error:", err)
	}
	return string(b)
}

// newClient returns a new discovery object with an authenticated AppEngine client.
func newClient() (*discovery, error) {
	d := &discovery{
		project: "mlab-sandbox",
	}

	var err error
	scopes := strings.Split(*scopeList, ",")
	// Create a new authenticated HTTP client.
	d.client, err = google.DefaultClient(oauth2.NoContext, scopes...)
	if err != nil {
		return nil, fmt.Errorf("Error setting up AppEngine client: %s", err)
	}

	// Create a new AppEngine service instance.
	d.apis, err = appengine.New(d.client)
	if err != nil {
		return nil, fmt.Errorf("Error setting up AppEngine client: %s", err)
	}

	return d, nil
}

// getLabels creates a target configuration for a prometheus service discovery
// file. The given service version should have a "SERVING" status, the instance
// should be in a "RUNNING" state and have at least one forwarded port.
//
// In serialized form, the label set look like:
//   {
//       "labels": {
//           "__aef_instance": "aef-etl--parser-20170418t195100-abcd",
//           "__aef_max_total_instances": "20",
//           "__aef_project": "mlab-sandbox",
//           "__aef_public_protocol": "tcp",
//           "__aef_service": "etl-parser",
//           "__aef_version": "20170418t195100",
//           "__aef_vm_debug_enabled": "true"
//       },
//       "targets": [
//           "104.196.220.184:9090"
//       ]
//   }
func getLabels(service *appengine.Service, version *appengine.Version, instance *appengine.Instance) map[string]interface{} {
	labels := map[string]string{
		aefLabelProject:      *project,
		aefLabelService:      service.Id,
		aefLabelVersion:      version.Id,
		aefLabelInstance:     instance.Id,
		aefMaxTotalInstances: fmt.Sprintf("%d", version.AutomaticScaling.MaxTotalInstances),
		aefVmDebugEnabled:    fmt.Sprintf("%t", instance.VmDebugEnabled),
	}
	if strings.HasSuffix(version.Network.ForwardedPorts[0], "/udp") {
		labels[aefLabelPublicProto] = "udp"
	} else if strings.HasSuffix(version.Network.ForwardedPorts[0], "/tcp") {
		labels[aefLabelPublicProto] = "tcp"
	} else {
		labels[aefLabelPublicProto] = "both"
	}

	// TODO(dev): collect max resource sizes: cpu, memory, disk.
	//   Resources.Cpu
	//   Resources.DiskGb
	//   Resources.MemoryGb
	//   Resources.Volumes[0].Name
	//   Resources.Volumes[0].SizeGb
	//   Resources.Volumes[0].VolumeType

	// TODO: do we need to support multiple forwarded ports? How to choose?
	// Extract target address in the form of the VM public IP and forwarded port.
	re := regexp.MustCompile("([0-9]+)(/.*)")
	port := re.ReplaceAllString(version.Network.ForwardedPorts[0], "$1")
	targets := []string{fmt.Sprintf("%s:%s", instance.VmIp, port)}

	// Construct a record for the Prometheus file service discovery format.
	// https://prometheus.io/docs/operating/configuration/#<file_sd_config>
	values := map[string]interface{}{
		"labels":  labels,
		"targets": targets,
	}
	return values
}

// TODO(dev): reduce nesting.
// listVms walks through every AppEngine service, looks at every serving
// version. listVms returns a list of every running instance in a form suitable
// for export to a prometheus service discovery file.
func listVms(client *discovery) ([]map[string]interface{}, error) {
	var err error
	targets := make([]map[string]interface{}, 0)

	s := client.apis.Apps.Services.List(client.project)
	// List all services.
	err = s.Pages(nil, func(listSvc *appengine.ListServicesResponse) error {
		for _, service := range listSvc.Services {

			// List all versions of each service.
			v := client.apis.Apps.Services.Versions.List(client.project, service.Id)
			err = v.Pages(nil, func(listVer *appengine.ListVersionsResponse) error {
				for _, version := range listVer.Versions {

					if version.ServingStatus != "SERVING" {
						continue
					}
					// List instances associated with each service version.
					l := client.apis.Apps.Services.Versions.Instances.List(
						client.project, service.Id, version.Id)
					err = l.Pages(nil, func(listInst *appengine.ListInstancesResponse) error {
						for _, instance := range listInst.Instances {
							if instance.VmStatus != "RUNNING" {
								continue
							}
							// Ignore instances without networks or forwarded ports.
							if version.Network == nil {
								continue
							}
							if len(version.Network.ForwardedPorts) == 0 {
								continue
							}
							targets = append(targets, getLabels(service, version, instance))
						}
						return nil
					})
				}
				return err
			})
		}
		return err
	})
	return targets, err
}

func main() {
	flag.Parse()

	// TODO(dev): run in a loop as a service.
	// TODO(dev): handle errors.
	client, err := newClient()
	if err != nil {
		panic(err)
	}

	// Collect AE Flex targets and labels.
	values, err := listVms(client)
	if err != nil {
		fmt.Printf("Error: %s", err)
	}

	// Convert to JSON.
	data, err := json.MarshalIndent(values, "", "    ")
	if err != nil {
		panic(err)
	}

	// Save targets to output file.
	err = ioutil.WriteFile(*filename, data, 0644)
	if err != nil {
		panic(err)
	}
	return
}
