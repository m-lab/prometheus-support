package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"strings"
	"time"

	// "github.com/kr/pretty"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"

	appengine "google.golang.org/api/appengine/v1"
	compute "google.golang.org/api/compute/v1"
)

func PrettyPrint(results map[string]string) {
	b, err := json.MarshalIndent(results, "", "  ")
	if err != nil {
		fmt.Println("error:", err)
	}
	fmt.Print(string(b))
}

const (
	gceLabel               = "__gce_"
	gceLabelProject        = gceLabel + "project"
	gceLabelZone           = gceLabel + "zone"
	gceLabelNetwork        = gceLabel + "network"
	gceLabelSubnetwork     = gceLabel + "subnetwork"
	gceLabelPublicIP       = gceLabel + "public_ip"
	gceLabelPrivateIP      = gceLabel + "private_ip"
	gceLabelInstanceName   = gceLabel + "instance_name"
	gceLabelInstanceStatus = gceLabel + "instance_status"
	gceLabelTags           = gceLabel + "tags"
	gceLabelMetadata       = gceLabel + "metadata_"

	// Constants for instrumentation.
	namespace = "prometheus"
)

var (
	defaultScopes = []string{compute.ComputeReadonlyScope, appengine.CloudPlatformScope,
		appengine.AppengineAdminScope}
)

var (
	project     = flag.String("project", "mlab-sandbox", "project name")
	serviceName = flag.String("service", "etl-parser-soltesz", "service name")
	versionName = flag.String("version", "20170418t195100", "service version")
	port        = flag.Int("port", 9090, "port number to scrape.")
	interval    = flag.Int("interval", 60, "Number of seconds between polling.")
	scopes      = flag.String("scopes", strings.Join(defaultScopes, ","), "Comma separated list of scopes to use.")
)

type Discovery struct {
	project string
	service string
	version string

	client  *http.Client
	apis    *appengine.APIService
	apisvc  *appengine.AppsServicesService
	apiver  *appengine.AppsServicesVersionsService
	apiinst *appengine.AppsServicesVersionsInstancesService

	interval     time.Duration
	port         int
	tagSeparator string
}

// NewAppsServicesVersionsService(s *APIService) *AppsServicesVersionsService
// NewAppsServicesService(s *APIService) *AppsServicesService

// NewDiscovery returns a new Discovery which periodically refreshes its targets.
func NewClient() (*Discovery, error) {
	d := &Discovery{
		project:      "mlab-sandbox",
		service:      *serviceName,
		version:      *versionName,
		interval:     time.Duration(*interval) * time.Duration(time.Second),
		port:         *port,
		tagSeparator: ",",
	}

	var err error
	// TODO(soltesz): parse scopes.
	s := strings.Split(*scopes, ",")
	d.client, err = google.DefaultClient(oauth2.NoContext, s...)
	if err != nil {
		return nil, fmt.Errorf("error setting up communication with GCE service: %s", err)
	}

	// AppEngine
	d.apis, err = appengine.New(d.client)
	if err != nil {
		return nil, fmt.Errorf("error setting up client for AppEngine service: %s", err)
	}

	d.apisvc = appengine.NewAppsServicesService(d.apis)
	d.apiver = appengine.NewAppsServicesVersionsService(d.apis)
	d.apiinst = appengine.NewAppsServicesVersionsInstancesService(d.apis)

	return d, nil
}

func listApps(d *Discovery) {
	s := d.apisvc.List(d.project)
	// List all services.
	s.Pages(nil, func(listSvc *appengine.ListServicesResponse) error {
		for _, service := range listSvc.Services {
			// List all versions of each service.
			v := d.apiver.List(d.project, service.Id)
			v.Pages(nil, func(listVer *appengine.ListVersionsResponse) error {
				for _, version := range listVer.Versions {
					// List instances associated with each service version.
					if version.ServingStatus != "SERVING" {
						continue
					}
					l := d.apiinst.List(d.project, service.Id, version.Id)
					_ = l.Pages(nil, func(listInst *appengine.ListInstancesResponse) error {
						for _, instance := range listInst.Instances {
							if instance.VmStatus != "RUNNING" {
								continue
							}
							//pretty.Print(service)
							//pretty.Print(version)
							//pretty.Print(instance)
							if version.Network != nil {
								if len(version.Network.ForwardedPorts) > 0 {
									fmt.Printf("%s %s:%s\n", service.Id, instance.VmIp, strings.Replace(version.Network.ForwardedPorts[0], "/tcp", "", 1))
								}
							}
						}
						return nil
					})
				}
				return nil
			})

		}
		return nil
	})
	return
}

func main() {
	flag.Parse()
	d, err := NewClient()
	if err != nil {
		panic(err)
	}

	listApps(d)
	return

	/*
		ilc := d.isvc.List(d.project, d.zone)
		if len(d.filter) > 0 {
			fmt.Println("USING FILTER:", d.filter)
			ilc = ilc.Filter(d.filter)
		}
		err = ilc.Pages(nil, func(l *compute.InstanceList) error {
			for _, inst := range l.Items {
				if len(inst.NetworkInterfaces) == 0 {
					continue
				}
				labels := map[string]string{
					gceLabelProject:        d.project,
					gceLabelZone:           inst.Zone,
					gceLabelInstanceName:   inst.Name,
					gceLabelInstanceStatus: inst.Status,
				}
				priIface := inst.NetworkInterfaces[0]
				labels[gceLabelNetwork] = priIface.Network
				labels[gceLabelSubnetwork] = priIface.Subnetwork
				labels[gceLabelPrivateIP] = priIface.NetworkIP
				addr := fmt.Sprintf("%s:%d", priIface.NetworkIP, d.port)
				labels["__address__"] = addr

				// Tags in GCE are usually only used for networking rules.
				if inst.Tags != nil && len(inst.Tags.Items) > 0 {
					// We surround the separated list with the separator as well. This way regular expressions
					// in relabeling rules don't have to consider tag positions.
					tags := d.tagSeparator + strings.Join(inst.Tags.Items, d.tagSeparator) + d.tagSeparator
					labels[gceLabelTags] = tags
				}

				// GCE metadata are key-value pairs for user supplied attributes.
				if inst.Metadata != nil {
					for _, i := range inst.Metadata.Items {
						// Protect against occasional nil pointers.
						if i.Value == nil {
							continue
						}
						name := i.Key
						labels[gceLabelMetadata+name] = *i.Value
					}
				}

				if len(priIface.AccessConfigs) > 0 {
					ac := priIface.AccessConfigs[0]
					if ac.Type == "ONE_TO_ONE_NAT" {
						labels[gceLabelPublicIP] = ac.NatIP
					}
				}
				PrettyPrint(labels)
			}
			return nil
		})
		if err != nil {
			panic(fmt.Errorf("error retrieving refresh targets from gce: %s", err))
		}
	*/
}
