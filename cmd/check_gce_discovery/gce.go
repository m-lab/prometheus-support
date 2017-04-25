// Copyright 2015 The Prometheus Authors
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/kr/pretty"
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
	zone    = flag.String("zone", "us-east1-b", "GCE zone name to query")
	filter  = flag.String("filter", "", "An Instances.List filter")
	service = flag.String("service", "etl-parser-soltesz", "service name")
	version = flag.String("version", "20170418t195100", "service version")
)

type GCEDiscovery struct {
	project      string
	zone         string
	filter       string
	client       *http.Client
	svc          *compute.Service
	isvc         *compute.InstancesService
	apps         *appengine.APIService
	appsvc       *appengine.AppsServicesVersionsInstancesService
	interval     time.Duration
	port         int
	tagSeparator string
}

// NewGCEDiscovery returns a new GCEDiscovery which periodically refreshes its targets.
func NewClient() (*GCEDiscovery, error) {
	gd := &GCEDiscovery{
		project:      "mlab-sandbox",
		zone:         *zone,
		filter:       *filter,
		interval:     time.Duration(60 * time.Second),
		port:         9090,
		tagSeparator: ",",
	}
	fmt.Println("FILTER1:", *filter)
	fmt.Println("FILTER2:", gd.filter)

	var err error
	gd.client, err = google.DefaultClient(oauth2.NoContext, compute.ComputeReadonlyScope, appengine.CloudPlatformScope, appengine.AppengineAdminScope)
	if err != nil {
		return nil, fmt.Errorf("error setting up communication with GCE service: %s", err)
	}
	// compute engine.
	gd.svc, err = compute.New(gd.client)
	if err != nil {
		return nil, fmt.Errorf("error setting up communication with GCE service: %s", err)
	}
	gd.isvc = compute.NewInstancesService(gd.svc)

	// app engine
	gd.apps, err = appengine.New(gd.client)
	if err != nil {
		return nil, fmt.Errorf("error setting up client for AppEngine service: %s", err)
	}
	gd.appsvc = appengine.NewAppsServicesVersionsInstancesService(gd.apps)
	return gd, nil
}

func listApps(gd *GCEDiscovery) {
	l := gd.appsvc.List("mlab-sandbox", *service, *version)
	_ = l.Pages(nil, func(resp *appengine.ListInstancesResponse) error {
		pretty.Print(resp)
		return nil
	})
	return
}

func main() {
	flag.Parse()
	gd, err := NewClient()
	if err != nil {
		panic(err)
	}

	listApps(gd)
	return

	ilc := gd.isvc.List(gd.project, gd.zone)
	if len(gd.filter) > 0 {
		fmt.Println("USING FILTER:", gd.filter)
		ilc = ilc.Filter(gd.filter)
	}
	err = ilc.Pages(nil, func(l *compute.InstanceList) error {
		for _, inst := range l.Items {
			if len(inst.NetworkInterfaces) == 0 {
				continue
			}
			labels := map[string]string{
				gceLabelProject:        gd.project,
				gceLabelZone:           inst.Zone,
				gceLabelInstanceName:   inst.Name,
				gceLabelInstanceStatus: inst.Status,
			}
			priIface := inst.NetworkInterfaces[0]
			labels[gceLabelNetwork] = priIface.Network
			labels[gceLabelSubnetwork] = priIface.Subnetwork
			labels[gceLabelPrivateIP] = priIface.NetworkIP
			addr := fmt.Sprintf("%s:%d", priIface.NetworkIP, gd.port)
			labels["__address__"] = addr

			// Tags in GCE are usually only used for networking rules.
			if inst.Tags != nil && len(inst.Tags.Items) > 0 {
				// We surround the separated list with the separator as well. This way regular expressions
				// in relabeling rules don't have to consider tag positions.
				tags := gd.tagSeparator + strings.Join(inst.Tags.Items, gd.tagSeparator) + gd.tagSeparator
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
}
