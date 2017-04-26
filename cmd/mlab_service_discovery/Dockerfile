FROM golang:1.8
COPY . /go/src/mlab_service_discovery
RUN go get -v mlab_service_discovery
ENTRYPOINT ["/go/bin/mlab_service_discovery"]
