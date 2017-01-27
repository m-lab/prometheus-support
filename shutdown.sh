#!/bin/bash

set -ex
kubectl delete deployment prometheus
kubectl delete service prometheus
